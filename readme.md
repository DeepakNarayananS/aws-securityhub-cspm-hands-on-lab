# 🛡️ AWS Security Hub CSPM Hands-On Lab
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.6.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/AWS%20Provider-%3E%3D6.60.0-FF9900?logo=amazon-aws&logoColor=white)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Security Standard](https://img.shields.io/badge/Standard-AWS%20FSBP%20v1.0.0-10B981)](#-security-controls-demonstrated)
[![Region](https://img.shields.io/badge/Region-ap--south--1%20(Mumbai)-blue)](#-architecture--scope)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
An end-to-end, single-account, single-Region **Cloud Security Posture Management (CSPM)** hands-on lab built with **Terraform**. 
This lab demonstrates how enterprise security teams aggregate telemetry from multiple native AWS security services into **AWS Security Hub**, automate triage metadata, and execute closed-loop, event-driven remediation with **Amazon EventBridge** and **AWS Lambda**.
Included is an illustrated **19-Page Hand-Drawn Notebook Guide (PDF)** and an **Interactive Digital Companion (HTML Flipbook)** with copyable code snippets.
---
## 📑 Table of Contents
- [🎯 Objectives & Scope](#-objectives--scope)
- [🏗️ Lab Architecture](#️-lab-architecture)
- [📦 What Terraform Deploys (24 Resources)](#-what-terraform-deploys-24-resources)
- [💰 Cost & Resource Model](#-cost--resource-model)
- [⚙️ Prerequisites & Installation](#️-prerequisites--installation)
- [🚀 Quick Deployment (One-Click)](#-quick-deployment-one-click)
- [🔧 Manual Deployment Steps](#-manual-deployment-steps)
- [🧪 Step-by-Step Test Scenarios](#-step-by-step-test-scenarios)
- [⚡ Event-Driven Auto-Remediation Flow](#-event-driven-auto-remediation-flow)
- [🧹 Complete Cleanup & Teardown](#-complete-cleanup--teardown)
- [🛠️ Troubleshooting & State Commands](#️-troubleshooting--state-commands)
- [📖 Hand-Drawn Guide & Interactive Notebook](#-hand-drawn-guide--interactive-notebook)
- [⚖️ Production Safety Guardrails](#️-production-safety-guardrails)
---
## 🎯 Objectives & Scope
* **Continuous Compliance:** Enable **AWS Security Hub CSPM** backed by **AWS Config** and the **AWS Foundational Security Best Practices (FSBP v1.0.0)** benchmark.
* **Unified Telemetry Stream:** Stream findings from **GuardDuty** (threats), **Inspector** (software CVEs), and **Macie** (sensitive S3 data) into standard **AWS Security Finding Format (ASFF)**.
* **Custom Insights:** Group and prioritize findings using Terraform-created decision matrices (`High-Critical-by-Product`, `High-Critical-by-Resource`, `Recent-High-by-Workflow`).
* **Automation Rules vs. Resource Remediation:** Clearly distinguish between modifying finding metadata (triage status, notes) and modifying live AWS infrastructure.
* **Closed-Loop Auto-Remediation:** Trigger a Security Hub Custom Action (`AutoRemediateSSH`) that routes through EventBridge to a Python Lambda function to revoke non-compliant ingress (`0.0.0.0/0:22`).
* **Clean Teardown:** Single-command teardown with `terraform destroy` and zero leftover infrastructure.
> **Scope Note:** This lab intentionally uses the Terraform `aws_securityhub_account` resource focused on classic CSPM standards, finding flows, and automated remediation. It excludes AWS Firewall Manager, EC2 runtime instances, NAT Gateways, and cross-region aggregators to keep deployment swift and cost-effective.
---
## 🏗️ Lab Architecture
```text
                     Single AWS Account  /  Region: ap-south-1 (Mumbai)
                                          │
            ┌─────────────────────────────┼─────────────────────────────┐
            │                             │                             │
    AWS Config (Recorder)      Amazon GuardDuty              Amazon Inspector
    (Continuous Evaluation)     (Threat Telemetry)          (Lambda Workload Scan)
            │                             │                             │
            └─────────────────────────────┼─────────────────────────────┘
                                          │
                                     Amazon Macie
                                (S3 Sensitive Data PII)
                                          │
                                          ▼
                             ┌─────────────────────────┐
                             │    AWS Security Hub     │
                             │   CSPM / FSBP Standard  │
                             │   Findings & Insights   │
                             └────────────┬────────────┘
                                          │
               ┌──────────────────────────┴──────────────────────────┐
               │                                                     │
               ▼                                                     ▼
     Security Hub Automation Rules                         Security Hub Custom Action
       (LAB-HIGH & CRITICAL TRIAGE)                           ("AutoRemediateSSH")
       • Updates Workflow: NOTIFIED                                  │
       • Appends Audit Triage Note                                   ▼
       (Changes Finding Metadata only)                      Amazon EventBridge Rule
                                                                     │
                                                                     ▼
                                                            AWS Lambda Remediator
                                                          (Python 3.12 + Boto3)
                                                                     │
                                                                     ▼
                                                           Revoke 0.0.0.0/0:22
                                                         from Lab Security Group
                                                                     │
                                                                     ▼
                                                         Config Re-evaluates ->
                                                        Finding marked COMPLIANT
📦 What Terraform Deploys (24 Resources)
Component	Resource Type	Description
Security Hub	aws_securityhub_account	CSPM account enablement (v1 model)
Security Hub	aws_securityhub_standards_subscription	AWS Foundational Security Best Practices v1.0.0
Security Hub	aws_securityhub_insight (x3)	Decision matrices: by Product, by Resource, by Workflow
Security Hub	aws_securityhub_automation_rule (x2)	LAB-HIGH-TRIAGE and LAB-CRITICAL-TRIAGE metadata enrichers
Security Hub	aws_securityhub_action_target	Custom Action target AutoRemediateSSH
AWS Config	aws_config_configuration_recorder	Records 9 resource types (EC2, S3, Lambda, VPC, Subnet, etc.)
AWS Config	aws_config_delivery_channel	Daily snapshot delivery to private S3 bucket
Threat & Data	aws_guardduty_detector	Active detector publishing every 15 minutes
Threat & Data	aws_macie2_account	Sensitive data discovery enabled
Threat & Data	aws_inspector2_enabler	Automated vulnerability scanning for Lambda functions
Storage	aws_s3_bucket (x2)	Private Config log bucket + Macie test bucket with synthetic data
Compute / Bait	aws_security_group	Insecure bait resource with open SSH (0.0.0.0/0:22) for EC2.13
Compute / Bait	aws_lambda_function (vulnerable)	Lambda running pinned outdated requests==2.20.0 for Inspector
Remediation	aws_cloudwatch_event_rule	EventBridge rule matching custom action name
Remediation	aws_cloudwatch_event_target	Routes EventBridge events to the remediator Lambda
Remediation	aws_lambda_function (remediator)	Python 3.12 function with scoped safety guards
IAM	aws_iam_role & policies	Least-privilege roles for Config, Vulnerable Lambda, and Remediator
💰 Cost & Resource Model
Target Region: ap-south-1 (Mumbai).
Minimal Footprint: No EC2 instances, ELBs, RDS databases, or NAT Gateways.
Storage: All buckets use force_destroy = true for clean teardown.
AWS Free Tier / Trial Friendly: Most services utilized (GuardDuty, Inspector, Macie, Security Hub) offer 30-day free trials for new accounts.
Tear down after completion: Always execute terraform destroy when done to ensure zero lingering costs.
⚙️ Prerequisites & Installation
System Requirements
Windows 10/11, macOS, or Linux
PowerShell 5.1+ (Windows) or Bash
Active AWS Account with Admin or PowerUser IAM permissions
1. Install Tools (Windows automated)
Run the bundled installer from an elevated PowerShell window:

powershell


.\Install-Prerequisites.ps1
Or install manually using winget:

powershell


winget install --id Amazon.AWSCLI --exact
winget install --id Hashicorp.Terraform --exact
2. Verify Versions
bash


aws --version        # Requires AWS CLI v2.x
terraform version    # Requires >= 1.6.0, < 2.0.0
3. Authenticate to AWS
Choose one of two standard options:

Option A: IAM Identity Center (SSO - Recommended)
powershell


aws configure sso
aws sso login --profile securityhub-lab
$env:AWS_PROFILE = "securityhub-lab"
Option B: Dedicated Lab IAM Profile
powershell


aws configure --profile securityhub-lab
# Enter Access Key, Secret Key, Default Region: ap-south-1
$env:AWS_PROFILE = "securityhub-lab"
$env:AWS_REGION  = "ap-south-1"
$env:AWS_DEFAULT_REGION = "ap-south-1"
Verify your active identity:

powershell


aws sts get-caller-identity --output table
🚀 Quick Deployment (One-Click)
Open File Explorer and navigate to the project directory.
Double-click START-HERE.cmd to view the runbook instructions.
Double-click Deploy-Lab.cmd.
The script runs pre-flight checks, verifies authentication, executes terraform init, validate, and plan.
When prompted, type APPLY to create all 24 resources.
🔧 Manual Deployment Steps
If deploying manually via command line:

powershell


# 1. Navigate to the terraform directory
cd terraform
# 2. Initialize Terraform and providers
terraform init -upgrade
# 3. Validate configuration syntax
terraform validate
# 4. Generate and review execution plan
terraform plan -out=tfplan
# 5. Apply the plan
terraform apply tfplan
# 6. View outputs (Console URLs, Resource IDs)
terraform output
🧪 Step-by-Step Test Scenarios
Scenario 1: Verify CSPM Open SSH Finding (EC2.13)
Terraform deployed security group securityhub-cspm-lab-open-ssh with open port 22.

In the AWS Console, open Security Hub → Findings.
Filter by: Control ID = EC2.13.
Observe finding: "Security groups should not allow ingress from 0.0.0.0/0 to port 22" (Status: CRITICAL / HIGH, Compliance: NON-COMPLIANT).
Scenario 2: Ingest GuardDuty Threat Telemetry
Generate synthetic findings to verify threat telemetry streaming into Security Hub:

powershell


$DetectorId = (aws guardduty list-detectors --region ap-south-1 --query "DetectorIds[0]" --output text)
aws guardduty create-sample-findings --region ap-south-1 --detector-id $DetectorId
Navigate to Security Hub → Findings → filter Product Name = GuardDuty (propagates in ~3–5 minutes).

Scenario 3: Ingest Macie Sensitive Data Telemetry
Generate synthetic S3 data discovery findings:

powershell


aws macie2 create-sample-findings --region ap-south-1
Navigate to Security Hub → Findings → filter Product Name = Macie.

Scenario 4: Inspector Workload & Code Vulnerability Scan
The lab deployed function securityhub-cspm-lab-vulnerable with requests==2.20.0:

In Security Hub → Findings → filter Product Name = Inspector.
Observe multiple CVEs flagged against the Lambda artifact (e.g., CVE-2024-47081, CVE-2023-32681).
Scenario 5: Review Custom Security Hub Insights
Navigate to Security Hub → Insights to view the 3 custom analytics widgets:

LAB-High-Critical-by-Product: Concentration of severe risk grouped by service.
LAB-High-Critical-by-Resource: Specific cloud resources holding the highest risk.
LAB-Recent-High-by-Workflow: New findings from the past 24 hours categorized by triage state.
Scenario 6: Verify Automation Rules
Open Security Hub → Automations:

Verify that new HIGH findings receive automatic audit notes and status NOTIFIED via LAB-HIGH-TRIAGE.
Verify that CRITICAL findings receive immediate review flags via LAB-CRITICAL-TRIAGE.
⚡ Event-Driven Auto-Remediation Flow
To remediate the open SSH security group with a single governed click:

In the Security Hub Console, open Findings.
Select the finding for EC2.13 (or the lab security group).
Click the top-right Actions ▾ menu → select AutoRemediateSSH.
A green confirmation banner appears: "Successfully started action: AutoRemediateSSH".
What happens behind the scenes:
Security Hub triggers the custom action target.
Amazon EventBridge catches detail-type Security Hub Findings - Custom Action.
EventBridge triggers securityhub-cspm-lab-remediator Lambda.
The Lambda strips 0.0.0.0/0:22 and ::/0:22 ingress rules using the AWS EC2 API.
AWS Config detects the change, re-evaluates the rule, and flips the finding status from NON-COMPLIANT to COMPLIANT.
Verify Ingress Revocation via CLI:
powershell


$SgId = terraform -chdir=terraform output -raw lab_security_group_id
aws ec2 describe-security-groups --group-ids $SgId --region ap-south-1 --query "SecurityGroups[0].IpPermissions" --output json
# Returns [] (Empty ingress rules)
⚖️ Production Safety Guardrails
Automated remediation in cloud environments requires strict boundaries to prevent operational disruption:

python


# Extract from lambda/remediator/handler.py
LAB_SG = os.environ.get("LAB_SECURITY_GROUP_ID")
# HARD SAFETY GUARD: Only modify the designated Terraform lab group!
if LAB_SG:
    targets = [x for x in targets if x == LAB_SG]
Target Scoping: The Lambda strictly ignores any security group whose ID does not match the LAB_SECURITY_GROUP_ID environment variable.
Least-Privilege IAM: The remediator role is constrained to ec2:DescribeSecurityGroups and ec2:RevokeSecurityGroupIngress.
Human-in-the-Loop: Triggered intentionally via a Security Hub Custom Action rather than a fully autonomous blind trigger.
🧹 Complete Cleanup & Teardown
To avoid ongoing AWS charges after completing the lab:

Automated Teardown:
Double-click Cleanup-Lab.cmd and type DESTROY when prompted.

Manual Teardown:
powershell


cd terraform
terraform destroy -auto-approve
10-Point Manual Verification Checklist:
Ensure the following services are disabled or empty in ap-south-1:

 Security Hub: Standards disabled
 GuardDuty: Detector removed
 Inspector: Lambda scanning disabled
 Macie: Account session suspended/disabled
 AWS Config: Configuration recorder deleted
 S3 Buckets: Both log and test buckets destroyed
 Security Group: Insecure lab security group removed
 Lambda Functions: Both vulnerable and remediator functions deleted
 EventBridge: Custom action rule deleted
 IAM Roles: Service execution roles deleted
🛠️ Troubleshooting & State Commands
Symptom	Root Cause	Solution
command not found: aws	PATH environment variable not refreshed	Reopen PowerShell or restart terminal session.
No available configuration recorder	Security Hub Config recorder sync delay	Wait 2–3 minutes for recorder to reach SUCCESS status before subscribing to standards.
AccessDenied: iam:PassRole	Deployment identity missing IAM permissions	Use an identity with AdministratorAccess or appropriate role policies.
Findings delayed in Security Hub	Standard service polling intervals	GuardDuty & Macie sample findings take 3–5 minutes to stream into Security Hub.
Useful Terraform State Commands:
powershell


# List all resources tracked by state
terraform state list
# Inspect security group resource state
terraform state show aws_security_group.lab_open_ssh
# Force unlock in case of abrupt exit
terraform force-unlock <LOCK-ID>
📖 Hand-Drawn Guide & Interactive Notebook
This repository contains two visual companions for studying and presenting this lab:

📄 AWS_CSPM_Hands_On_Guide_Deepak.pdf
A full 19-page illustrated workbook ("A Gemini Notebook by Deepak") featuring hand-drawn diagrams, architecture flows, CISO executive pillars, and command cheat sheets. Ideal for reading or uploading as a LinkedIn document carousel.

💻 AWS-CSPM-HandDrawn-Notebook.html
A self-contained interactive digital notebook (flipbook) with:

High-definition page-by-page viewing (Next / Prev / Keyboard navigation)
Slide-out "Deep-Dive & Code" drawer for each page
One-click copy buttons for all Terraform and CLI commands
Zero external dependencies (all 19 pages Base64 embedded; runs offline in any browser)
📜 License
This project is open-source and available under the MIT License

Built with ❤️ for cloud security enthusiasts, DevSecOps practitioners, and cybersecurity learners.