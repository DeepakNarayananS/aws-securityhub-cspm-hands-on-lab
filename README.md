# AWS Security Hub CSPM Hands-On Lab — Windows + Terraform

## Purpose

## Scope note

This package targets **AWS Security Hub CSPM** using the Terraform `aws_securityhub_account` resource. It is intentionally focused on CSPM standards, findings, Insights, Automation Rules and Custom Actions; it does not deploy the newer unified Security Hub V2 account resource.

A beginner-friendly, single-account, single-Region lab for demonstrating:

- AWS Security Hub CSPM + AWS Foundational Security Best Practices
- AWS Config-backed Security Hub controls
- Amazon GuardDuty -> Security Hub
- Amazon Inspector Lambda/Lambda code scanning -> Security Hub
- Amazon Macie -> Security Hub
- Security Hub managed insights + Terraform-created custom insights
- Security Hub Automation Rules
- Security Hub Custom Action -> EventBridge -> Lambda remediation
- One-click-ish Windows deployment and cleanup

**Firewall Manager has been intentionally removed from this lab.** It is not part of the deployment, variables, code, or cleanup.

## Cost model

This is designed for a short training/presentation lab and uses one Region (default `ap-south-1`). It is not a promise of perpetual zero cost. AWS services can become billable after trials/free tiers or if you leave them enabled. Check current AWS pricing before deployment.

The lab intentionally avoids EC2, NAT Gateway, load balancers, RDS, and other unnecessary infrastructure.

## Architecture

```text
                 Single AWS account / ap-south-1
                              |
          +-------------------+-------------------+
          |                   |                   |
      AWS Config          GuardDuty           Inspector
          |                   |                   |
          +-------------------+-------------------+
                              |
                           Macie
                              |
                              v
                  +-----------------------+
                  |   Security Hub CSPM   |
                  | FSBP / Findings /     |
                  | Score / Insights      |
                  +-----------+-----------+
                              |
              +---------------+----------------+
              |                                |
       Automation Rules                 Custom Action
       finding metadata                        |
              |                                v
              |                           EventBridge
              |                                |
              |                                v
              |                              Lambda
              |                                |
              |                                v
              |                     Revoke public SSH
              |                        from lab SG
              +--------------------------------+
```

## Prerequisites

Windows 10/11, internet access, an AWS account, and an IAM identity/role with enough permissions to create the lab resources.

Install:

1. AWS CLI v2
2. Terraform CLI
3. Optional: Git

See `docs/AUTHENTICATION-WINDOWS.md` for authentication options.

## Fastest deployment

1. Extract the ZIP to a folder such as `C:\Labs\aws-securityhub-cspm-lab`.
2. Double-click `START-HERE.cmd`.
3. Read the PDF.
4. Run `Install-Prerequisites.ps1` if AWS CLI/Terraform are missing.
5. Authenticate to AWS.
6. Double-click `Deploy-Lab.cmd`.
7. Approve the Terraform plan when prompted.

The deployment script uses PowerShell and runs:

```powershell
terraform init
terraform validate
terraform plan
terraform apply
```

It does not embed AWS credentials in Terraform code.

## Manual deployment

From PowerShell:

```powershell
cd C:\Labs\aws-securityhub-cspm-lab
$env:AWS_REGION="ap-south-1"
aws sts get-caller-identity
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

## What Terraform creates

- Security Hub CSPM account enablement
- AWS Foundational Security Best Practices standard
- GuardDuty detector
- Inspector Lambda + Lambda code scanning
- Macie account enablement
- A private S3 bucket containing synthetic test data
- A deliberately insecure EC2 security group allowing public TCP/22
- A Lambda function for Inspector scanning
- Three Security Hub custom insights
- Two Security Hub automation rules
- A Security Hub custom action named `AutoRemediateSSH`
- EventBridge rule for that custom action
- Least-privilege remediation Lambda
- IAM roles/policies required by the two lab Lambdas

## Why no AWS Config resource is created by Terraform

When both Security Hub CSPM and Security Hub are enabled, AWS automatically creates and manages the service-linked AWS Config recorder needed for Security Hub controls. The recorder is named `AWSConfigurationRecorderForSecurityHubCSPM`. Do not create a competing customer-managed recorder for this lab.

## Test flow

### 1. CSPM finding

The lab security group deliberately allows:

```text
TCP 22 from 0.0.0.0/0
```

Wait for Security Hub to evaluate the resource, then filter findings for `EC2.13`.

### 2. GuardDuty sample findings

PowerShell:

```powershell
$Region = "ap-south-1"
$DetectorId = aws guardduty list-detectors --region $Region --query "DetectorIds[0]" --output text
aws guardduty create-sample-findings --region $Region --detector-id $DetectorId
```

Then Security Hub -> Findings -> Product name = GuardDuty.

### 3. Macie sample findings

```powershell
aws macie2 create-sample-findings --region ap-south-1
```

Then Security Hub -> Findings -> Product name = Macie.

### 4. Inspector

Inspector scanning is enabled for Lambda and Lambda code. The lab function is intentionally packaged with an old `requests` dependency so Inspector has a vulnerability-oriented artifact to analyze. Allow time for the service to analyze the function and then filter Security Hub findings by Inspector.

### 5. Insights

Open Security Hub -> Insights and show AWS-managed insights. Terraform also creates:

- `LAB-High-Critical-by-Product`
- `LAB-High-Critical-by-Resource`
- `LAB-Recent-High-by-Workflow`

### 6. Automation Rules

Terraform creates:

- `LAB-HIGH-TRIAGE`
- `LAB-CRITICAL-TRIAGE`

They update finding metadata (note/workflow). They do **not** change the underlying AWS resource.

### 7. EventBridge remediation

Select the `EC2.13` finding for the lab security group:

```text
Actions -> Auto-remediate public SSH
```

The path is:

```text
Security Hub finding
  -> Custom Action
  -> EventBridge
  -> Lambda
  -> Revoke 0.0.0.0/0:22
  -> Security Hub re-evaluates
```

The Lambda contains a hard safety guard and will only modify the Terraform-created security group ID stored in its environment variable.

## Cleanup

From the lab root, run:

```powershell
.\Cleanup-Lab.ps1
```

or:

```powershell
cd terraform
terraform destroy
```

Then verify in the AWS console that Security Hub, GuardDuty, Inspector and Macie are no longer enabled for this lab Region. Terraform-managed resources are removed by `terraform destroy`; manually enabled resources outside the Terraform state must be checked separately.

## Important warning

Do not put real personal data, production credentials, real payment-card data, or corporate secrets into the lab S3 bucket. The supplied data is synthetic.

Do not run the remediation Lambda against production security groups. This lab is intentionally constrained to its own Terraform-created security group.
