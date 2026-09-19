$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $Root 'terraform'
$DefaultRegion = 'ap-south-1'

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " AWS Security Hub CSPM Lab - Terraform Deployment" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
  throw "AWS CLI is not installed. Run Install-Prerequisites.ps1 first."
}
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "Terraform is not installed. Run Install-Prerequisites.ps1 first."
}

$Region = if ($env:AWS_REGION) { $env:AWS_REGION } else { $DefaultRegion }
$env:AWS_REGION = $Region
$env:AWS_DEFAULT_REGION = $Region
Write-Host "Region: $Region" -ForegroundColor Green

function Test-AwsIdentity {
  try {
    $null = aws sts get-caller-identity --output json 2>$null
    return $LASTEXITCODE -eq 0
  } catch { return $false }
}

if (-not (Test-AwsIdentity)) {
  Write-Host "No usable AWS CLI credentials were detected." -ForegroundColor Yellow
  Write-Host "Choose authentication method:" -ForegroundColor Cyan
  Write-Host "  1 = IAM Identity Center (recommended for organizations)"
  Write-Host "  2 = IAM access key profile (use only for a dedicated lab identity)"
  $choice = Read-Host "Enter 1 or 2"

  if ($choice -eq '1') {
    aws configure sso
    $profile = Read-Host "Enter the profile name created by the SSO wizard"
    if ([string]::IsNullOrWhiteSpace($profile)) { throw "Profile name is required." }
    aws sso login --profile $profile
    $env:AWS_PROFILE = $profile
  } elseif ($choice -eq '2') {
    $profile = Read-Host "Enter a profile name (example: securityhub-lab)"
    if ([string]::IsNullOrWhiteSpace($profile)) { $profile = 'securityhub-lab' }
    aws configure --profile $profile
    $env:AWS_PROFILE = $profile
  } else {
    throw "Invalid choice. Re-run Deploy-Lab.cmd and choose 1 or 2."
  }

  if (-not (Test-AwsIdentity)) {
    throw "AWS authentication failed. Run 'aws sts get-caller-identity --profile YOUR_PROFILE' and fix authentication before retrying."
  }
}

Write-Host "Authenticated AWS identity:" -ForegroundColor Green
aws sts get-caller-identity

Write-Host "`nTerraform version:" -ForegroundColor Green
terraform version

Write-Host "`n[1/4] terraform init" -ForegroundColor Cyan
terraform -chdir=$TfDir init -upgrade

Write-Host "`n[2/4] terraform validate" -ForegroundColor Cyan
terraform -chdir=$TfDir validate

Write-Host "`n[3/4] terraform plan" -ForegroundColor Cyan
terraform -chdir=$TfDir plan -out=tfplan

Write-Host "`nThe plan above is the exact infrastructure that will be created." -ForegroundColor Yellow
$confirm = Read-Host "Type APPLY to create the lab"
if ($confirm -ne 'APPLY') {
  Write-Host "Deployment cancelled. No terraform apply was executed." -ForegroundColor Yellow
  exit 0
}

Write-Host "`n[4/4] terraform apply" -ForegroundColor Cyan
terraform -chdir=$TfDir apply tfplan

Write-Host "`nDeployment complete." -ForegroundColor Green
Write-Host "Terraform outputs:" -ForegroundColor Cyan
terraform -chdir=$TfDir output

Write-Host "`nNext: open Security Hub in $Region, wait for the CSPM controls to evaluate, then follow the PDF runbook." -ForegroundColor Green
Read-Host "Press Enter to close"
