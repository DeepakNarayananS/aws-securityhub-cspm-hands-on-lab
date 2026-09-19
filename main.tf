data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

# ---------------------------------------------------------------------------
# AWS Config - required by Security Hub CSPM in the CSPM-only architecture.
#
# This lab deliberately does NOT enable Security Hub V2. In that architecture
# Security Hub CSPM requires AWS Config resource recording for its controls.
#
# Cost control:
# - Record only resource types needed by the lab/CSPM demonstration.
# - Do NOT record AWS::Config::ResourceCompliance; AWS recommends disabling
#   recording of this configuration item when Config is used only for CSPM.
# - The S3 bucket is private and force-destroyed with the lab.
#
# NOTE: AWS Config can still incur charges. "Zero cost" cannot be guaranteed.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "config" {
  bucket        = "${data.aws_caller_identity.current.account_id}-securityhub-cspm-config"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "config_bucket" {
  statement {
    sid    = "AWSConfigBucketPermissionsCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.config.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AWSConfigBucketDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = data.aws_iam_policy_document.config_bucket.json
}

# Security Hub CSPM already created this service-linked role in the current
# account. Terraform uses the role rather than attempting to recreate it.
data "aws_iam_role" "config_service_linked" {
  name = "AWSServiceRoleForConfig"
}

resource "aws_config_configuration_recorder" "securityhub" {
  name     = "securityhub-cspm-lab"
  role_arn = data.aws_iam_role.config_service_linked.arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false

    resource_types = [
      # Security Hub / EC2 CSPM demonstration
      "AWS::EC2::SecurityGroup",
      "AWS::EC2::VPC",
      "AWS::EC2::Subnet",
      "AWS::EC2::NetworkAcl",
      "AWS::EC2::RouteTable",

      # S3 CSPM demonstration
      "AWS::S3::Bucket",

      # Lambda CSPM demonstration
      "AWS::Lambda::Function",

      # KMS / CloudTrail controls may use these if enabled by the standard
      "AWS::KMS::Key",
      "AWS::CloudTrail::Trail"
    ]
  }

  depends_on = [
    aws_s3_bucket_policy.config
  ]
}

resource "aws_config_delivery_channel" "securityhub" {
  name           = "securityhub-cspm-lab"
  s3_bucket_name = aws_s3_bucket.config.id

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [
    aws_config_configuration_recorder.securityhub
  ]
}

resource "aws_config_configuration_recorder_status" "securityhub" {
  name       = aws_config_configuration_recorder.securityhub.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.securityhub
  ]
}

resource "aws_securityhub_account" "this" {
  enable_default_standards = false

  depends_on = [
    aws_config_configuration_recorder_status.securityhub
  ]
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  depends_on    = [aws_securityhub_account.this]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# Cross-region aggregation is intentionally not enabled. A single-region lab is
# cheaper and easier to explain.
resource "aws_securityhub_action_target" "auto_remediate_ssh" {
  depends_on  = [aws_securityhub_account.this]
  name        = "AutoRemediateSSH"
  identifier  = "AutoRemediateSSH"
  description = "Remove public 0.0.0.0/0 and ::/0 SSH ingress from the lab security group."
}

resource "aws_securityhub_insight" "high_critical_by_product" {
  depends_on = [aws_securityhub_account.this]

  name               = "LAB-High-Critical-by-Product"
  group_by_attribute = "ProductName"

  filters {
    record_state {
      comparison = "EQUALS"
      value      = "ACTIVE"
    }

    severity_label {
      comparison = "EQUALS"
      value      = "HIGH"
    }

    severity_label {
      comparison = "EQUALS"
      value      = "CRITICAL"
    }
  }
}

resource "aws_securityhub_insight" "high_critical_by_resource" {
  depends_on = [aws_securityhub_account.this]

  name               = "LAB-High-Critical-by-Resource"
  group_by_attribute = "ResourceId"

  filters {
    record_state {
      comparison = "EQUALS"
      value      = "ACTIVE"
    }

    severity_label {
      comparison = "EQUALS"
      value      = "HIGH"
    }

    severity_label {
      comparison = "EQUALS"
      value      = "CRITICAL"
    }
  }
}

resource "aws_securityhub_insight" "recent_high_by_workflow" {
  depends_on = [aws_securityhub_account.this]

  name               = "LAB-Recent-High-by-Workflow"
  group_by_attribute = "WorkflowStatus"

  filters {
    record_state {
      comparison = "EQUALS"
      value      = "ACTIVE"
    }

    severity_label {
      comparison = "EQUALS"
      value      = "HIGH"
    }

    created_at {
      date_range {
        unit  = "DAYS"
        value = 1
      }
    }
  }
}

resource "aws_securityhub_automation_rule" "critical_high_note" {
  depends_on = [aws_securityhub_account.this]

  description = "Demo: add a triage note and mark new HIGH findings as NOTIFIED."
  rule_name   = "LAB-HIGH-TRIAGE"
  rule_order  = 1
  rule_status = "ENABLED"

  criteria {
    severity_label {
      comparison = "EQUALS"
      value      = "HIGH"
    }

    workflow_status {
      comparison = "EQUALS"
      value      = "NEW"
    }
  }

  actions {
    finding_fields_update {
      note {
        text       = "LAB DEMO: HIGH finding automatically triaged by Security Hub automation."
        updated_by = "terraform-securityhub-lab"
      }

      workflow {
        status = "NOTIFIED"
      }
    }

    type = "FINDING_FIELDS_UPDATE"
  }
}

resource "aws_securityhub_automation_rule" "critical_triage" {
  depends_on = [aws_securityhub_account.this]

  description = "Demo: add a triage note to new CRITICAL findings."
  rule_name   = "LAB-CRITICAL-TRIAGE"
  rule_order  = 2
  rule_status = "ENABLED"

  criteria {
    severity_label {
      comparison = "EQUALS"
      value      = "CRITICAL"
    }

    workflow_status {
      comparison = "EQUALS"
      value      = "NEW"
    }
  }

  actions {
    finding_fields_update {
      note {
        text       = "LAB DEMO: CRITICAL finding requires immediate review."
        updated_by = "terraform-securityhub-lab"
      }
    }

    type = "FINDING_FIELDS_UPDATE"
  }
}

resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_macie2_account" "this" {
  status                       = "ENABLED"
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_inspector2_enabler" "lambda" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["LAMBDA"]
}

resource "aws_s3_bucket" "macie_lab" {
  bucket        = "${data.aws_caller_identity.current.account_id}-securityhub-cspm-macie-lab"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "macie_lab" {
  bucket = aws_s3_bucket.macie_lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "macie_test" {
  bucket  = aws_s3_bucket.macie_lab.id
  key     = "demo/financial-test.txt"
  content = <<-EOT
    SECURITY LAB TEST DATA - synthetic only
    Name: Alice Example
    Email: alice@example.invalid
    Card-like test value: 4111111111111111
    Do not use real personal or payment data in this lab.
  EOT

  etag = md5(<<-EOT
    SECURITY LAB TEST DATA - synthetic only
    Name: Alice Example
    Email: alice@example.invalid
    Card-like test value: 4111111111111111
    Do not use real personal or payment data in this lab.
  EOT
  )
}

data "archive_file" "vulnerable_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/vulnerable"
  output_path = "${path.module}/.build/vulnerable.zip"
}

resource "aws_iam_role" "lambda" {
  name = "securityhub-cspm-lab-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "vulnerable" {
  function_name    = "securityhub-cspm-lab-vulnerable"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.vulnerable_lambda.output_path
  source_code_hash = data.archive_file.vulnerable_lambda.output_base64sha256
  timeout          = 10
  memory_size      = 128

  depends_on = [aws_iam_role_policy_attachment.lambda_basic]
}

resource "aws_security_group" "lab_open_ssh" {
  name        = "securityhub-cspm-lab-open-ssh"
  description = "INTENTIONALLY INSECURE: Security Hub EC2.13/EC2.19 demonstration."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "INTENTIONALLY INSECURE - Security Hub demo"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Lab egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "archive_file" "remediator" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/remediator"
  output_path = "${path.module}/.build/remediator.zip"
}

resource "aws_iam_role" "remediator" {
  count = var.auto_remediation_enabled ? 1 : 0

  name = "securityhub-cspm-lab-remediator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "remediator" {
  count = var.auto_remediation_enabled ? 1 : 0

  role = aws_iam_role.remediator[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "remediator" {
  count = var.auto_remediation_enabled ? 1 : 0

  function_name    = "securityhub-cspm-lab-remediator"
  role             = aws_iam_role.remediator[0].arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.remediator.output_path
  source_code_hash = data.archive_file.remediator.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      LAB_SECURITY_GROUP_ID = aws_security_group.lab_open_ssh.id
    }
  }
}

resource "aws_cloudwatch_event_rule" "securityhub_custom_action" {
  count = var.auto_remediation_enabled ? 1 : 0

  name        = "securityhub-cspm-lab-custom-action"
  description = "Security Hub custom action -> lab remediation Lambda."

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Custom Action"]
    detail = {
      actionName = ["AutoRemediateSSH"]
    }
  })
}

resource "aws_cloudwatch_event_target" "remediator" {
  count = var.auto_remediation_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.securityhub_custom_action[0].name
  target_id = "SecurityHubLabRemediator"
  arn       = aws_lambda_function.remediator[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.auto_remediation_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromSecurityHubEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_custom_action[0].arn
}
