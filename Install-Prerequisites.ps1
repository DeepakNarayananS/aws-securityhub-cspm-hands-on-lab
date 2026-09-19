$ErrorActionPreference = 'Stop'
Write-Host "AWS Security Hub CSPM Lab - Windows prerequisites" -ForegroundColor Cyan

function Test-Command($name) {
  return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

if (Test-Command aws) {
  Write-Host "AWS CLI already installed:" -ForegroundColor Green
  aws --version
} else {
  Write-Host "AWS CLI not found." -ForegroundColor Yellow
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Installing AWS CLI with winget..." -ForegroundColor Cyan
    winget install --id Amazon.AWSCLI --exact --accept-package-agreements --accept-source-agreements
  } else {
    Write-Host "winget is unavailable. Install AWS CLI v2 from the official AWS installer:" -ForegroundColor Red
    Write-Host "https://aws.amazon.com/cli/" -ForegroundColor Yellow
  }
}

if (Test-Command terraform) {
  Write-Host "Terraform already installed:" -ForegroundColor Green
  terraform version
} else {
  Write-Host "Terraform not found." -ForegroundColor Yellow
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Installing Terraform with winget..." -ForegroundColor Cyan
    winget install --id Hashicorp.Terraform --exact --accept-package-agreements --accept-source-agreements
  } else {
    Write-Host "winget is unavailable. Install Terraform from the official HashiCorp installer:" -ForegroundColor Red
    Write-Host "https://developer.hashicorp.com/terraform/install" -ForegroundColor Yellow
  }
}

Write-Host "`nIf you installed either tool during this script, close this window and open a NEW PowerShell window, then run:" -ForegroundColor Yellow
Write-Host "  aws --version"
Write-Host "  terraform version"
Write-Host "`nNext: authenticate with AWS, then run Deploy-Lab.cmd." -ForegroundColor Green
Read-Host "Press Enter to finish"
