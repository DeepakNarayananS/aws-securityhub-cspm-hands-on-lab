output "aws_region" {
  value = data.aws_region.current.region
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "securityhub_console" {
  value = "https://${data.aws_region.current.region}.console.aws.amazon.com/securityhub/home?region=${data.aws_region.current.region}#/findings"
}

output "securityhub_standards_console" {
  value = "https://${data.aws_region.current.region}.console.aws.amazon.com/securityhub/home?region=${data.aws_region.current.region}#/standards"
}

output "aws_config_console" {
  value = "https://${data.aws_region.current.region}.console.aws.amazon.com/config/home?region=${data.aws_region.current.region}#/dashboard"
}

output "aws_config_recorder" {
  value = aws_config_configuration_recorder.securityhub.name
}

output "aws_config_bucket" {
  value = aws_s3_bucket.config.bucket
}

output "lab_security_group_id" {
  value = aws_security_group.lab_open_ssh.id
}

output "macie_lab_bucket" {
  value = aws_s3_bucket.macie_lab.bucket
}

output "vulnerable_lambda" {
  value = aws_lambda_function.vulnerable.function_name
}

output "remediator_lambda" {
  value = var.auto_remediation_enabled ? aws_lambda_function.remediator[0].function_name : null
}
