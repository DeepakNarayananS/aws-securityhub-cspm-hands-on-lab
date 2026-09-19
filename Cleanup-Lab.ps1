$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $Root 'terraform'

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "Terraform is not installed."
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
  throw "AWS CLI is not installed."
}

Write-Host "AWS Security Hub CSPM Lab - Cleanup" -ForegroundColor Cyan
aws sts get-caller-identity

Write-Host "`nTerraform will destroy only resources tracked by this lab's state." -ForegroundColor Yellow
Write-Host "Afterwards, manually verify that Security Hub, GuardDuty, Inspector and Macie are disabled if you no longer need them." -ForegroundColor Yellow
$confirm = Read-Host "Type DESTROY to continue"
if ($confirm -ne 'DESTROY') { Write-Host "Cleanup cancelled."; exit 0 }

terraform -chdir=$TfDir destroy

Write-Host "`nCleanup command finished." -ForegroundColor Green
Write-Host "IMPORTANT: check AWS console -> Security Hub, GuardDuty, Inspector and Macie in the lab Region." -ForegroundColor Yellow
Read-Host "Press Enter to close"
