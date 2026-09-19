import os
import re
import boto3

ec2 = boto3.client("ec2")

LAB_SG = os.environ.get("LAB_SECURITY_GROUP_ID")

def _sg_id(value):
    if not value:
        return None
    # Handles both sg-0123 and arn:aws:ec2:region:account:security-group/sg-0123
    m = re.search(r"(sg-[0-9a-fA-F]+)$", value)
    return m.group(1) if m else value if value.startswith("sg-") else None

def lambda_handler(event, context):
    findings = event.get("detail", {}).get("findings", [])
    targets = []

    for finding in findings:
        for resource in finding.get("Resources", []):
            if resource.get("Type") in ("AwsEc2SecurityGroup", "AWS::EC2::SecurityGroup"):
                sid = _sg_id(resource.get("Id"))
                if sid:
                    targets.append(sid)

    # Safety guard: this demo only changes the Terraform-created SG.
    if LAB_SG:
        targets = [x for x in targets if x == LAB_SG]

    results = []
    for sg_id in sorted(set(targets)):
        try:
            sg = ec2.describe_security_groups(GroupIds=[sg_id])["SecurityGroups"][0]
            for rule in sg.get("IpPermissions", []):
                if rule.get("IpProtocol") == "tcp" and rule.get("FromPort") == 22 and rule.get("ToPort") == 22:
                    ipv4 = [{"CidrIp": x["CidrIp"], "Description": x.get("Description")} for x in rule.get("IpRanges", []) if x.get("CidrIp") == "0.0.0.0/0"]
                    ipv6 = [{"CidrIpv6": x["CidrIpv6"], "Description": x.get("Description")} for x in rule.get("Ipv6Ranges", []) if x.get("CidrIpv6") == "::/0"]

                    if ipv4:
                        ec2.revoke_security_group_ingress(GroupId=sg_id, IpPermissions=[{
                            "IpProtocol": "tcp",
                            "FromPort": 22,
                            "ToPort": 22,
                            "IpRanges": [{"CidrIp": "0.0.0.0/0"}]
                        }])
                        results.append({"group": sg_id, "removed": "0.0.0.0/0:22"})

                    if ipv6:
                        ec2.revoke_security_group_ingress(GroupId=sg_id, IpPermissions=[{
                            "IpProtocol": "tcp",
                            "FromPort": 22,
                            "ToPort": 22,
                            "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
                        }])
                        results.append({"group": sg_id, "removed": "::/0:22"})
        except Exception as exc:
            results.append({"group": sg_id, "error": str(exc)})

    return {"remediated": results}
