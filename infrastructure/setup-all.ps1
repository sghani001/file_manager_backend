#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy the full CloudVault File Manager stack on AWS.

.DESCRIPTION
    Prompts for all required values (no hardcoded defaults), then deploys
    the CloudFormation template cloudvault-full-stack.yaml.

    After the stack is created it enables S3 EventBridge notifications,
    waits for EC2 to boot, and prints the frontend URL.

    Safe to commit to public GitHub — no secrets or personal values
    are embedded in the script.
#>

$ErrorActionPreference = 'Stop'
Write-Host '════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  CloudVault File Manager — AWS Provisioner' -ForegroundColor Cyan
Write-Host '════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''

# ── Prerequisites ───────────────────────────────────────────────────────────
Write-Host '>>> Checking prerequisites...' -ForegroundColor Cyan
$aws = Get-Command aws -ErrorAction SilentlyContinue
if (-not $aws) { throw 'AWS CLI not found. Install from https://aws.amazon.com/cli/' }

aws sts get-caller-identity --region us-east-1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'AWS CLI not authenticated. Run "aws configure" first.' }

$templatePath = Join-Path $PSScriptRoot 'cloudvault-full-stack.yaml'
if (-not (Test-Path $templatePath)) { throw "Template not found at $templatePath" }

Write-Host '  OK  Prerequisites met' -ForegroundColor Green
Write-Host ''

# ── Read all inputs ─────────────────────────────────────────────────────────
function Prompt-Required($label, $secret=$false) {
    $val = ''
    while (-not $val) {
        if ($secret) {
            $secure = Read-Host "  $label" -AsSecureString
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            $val = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        } else {
            $val = Read-Host "  $label"
        }
        if (-not $val) { Write-Host '    (this value is required)' -ForegroundColor Yellow }
    }
    return $val
}

function Prompt-Optional($label, $default) {
    $val = Read-Host "  $label [$default]"
    if (-not $val) { $val = $default }
    return $val
}

Write-Host '>>> Enter configuration values (all required unless a default is shown in brackets)' -ForegroundColor Cyan
Write-Host ''

$Region           = Prompt-Required 'AWS region                         (e.g. us-east-1)'
$StackName        = Prompt-Required 'CloudFormation stack name           (e.g. cloudvault-file-manager)'
$BucketName       = Prompt-Required 'S3 bucket name (globally unique)    (e.g. cloudvault-uploads-YOURNAME)'
$GithubBackend    = Prompt-Required 'GitHub backend repo URL             (e.g. https://github.com/you/backend.git)'
$GithubFrontend   = Prompt-Required 'GitHub frontend repo URL            (e.g. https://github.com/you/frontend.git)'
$GitBranch        = Prompt-Optional 'Git branch to deploy'               'main'
$DBUsername       = Prompt-Optional 'RDS database username'              'postgres'
$DBPassword       = Prompt-Required 'RDS master password'                $true
$RailsMasterKey   = Prompt-Required 'Rails master.key'                   $true
$JWTSecret        = Prompt-Required 'JWT secret'                         $true
$LambdaWebhookSecret = Prompt-Required 'Lambda webhook secret'           $true
$InstanceType     = Prompt-Optional 'EC2 instance type'                  't3.medium'

Write-Host ''
Write-Host '>>> Configuration summary:' -ForegroundColor Cyan
Write-Host "  Region:              $Region"
Write-Host "  Stack name:          $StackName"
Write-Host "  S3 bucket:           $BucketName"
Write-Host "  Backend repo:        $GithubBackend"
Write-Host "  Frontend repo:       $GithubFrontend"
Write-Host "  Git branch:          $GitBranch"
Write-Host "  DB username:         $DBUsername"
Write-Host "  DB password:         ********"
Write-Host "  EC2 instance type:   $InstanceType"
Write-Host ''

$confirm = Read-Host 'Proceed with deployment? [y/N]'
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host 'Aborted.' -ForegroundColor Yellow; exit 0
}

# ── Deploy CloudFormation ───────────────────────────────────────────────────
Write-Host ">>> Deploying stack '$StackName' to $Region (10-15 minutes)..." -ForegroundColor Cyan

aws cloudformation deploy `
    --template-file $templatePath `
    --stack-name $StackName `
    --parameter-overrides `
        BucketName=$BucketName `
        DBUsername=$DBUsername `
        DBPassword=$DBPassword `
        RailsMasterKey=$RailsMasterKey `
        JWTSecret=$JWTSecret `
        LambdaWebhookSecret=$LambdaWebhookSecret `
        InstanceType=$InstanceType `
        GithubBackendRepo=$GithubBackend `
        GithubFrontendRepo=$GithubFrontend `
        GitBranch=$GitBranch `
    --capabilities CAPABILITY_IAM `
    --region $Region

if ($LASTEXITCODE -ne 0) { throw "Stack deployment failed" }
Write-Host '  OK  Stack creation initiated' -ForegroundColor Green

# ── Wait for stack ──────────────────────────────────────────────────────────
Write-Host '>>> Waiting for stack creation to complete...' -ForegroundColor Cyan
aws cloudformation wait stack-create-complete --stack-name $StackName --region $Region
if ($LASTEXITCODE -ne 0) {
    aws cloudformation describe-stacks --stack-name $StackName --region $Region --query 'Stacks[0].StackStatus'
    throw "Stack did not reach CREATE_COMPLETE"
}
Write-Host '  OK  Stack creation complete' -ForegroundColor Green

# ── Get outputs ─────────────────────────────────────────────────────────────
$bucketName   = aws cloudformation describe-stacks --stack-name $StackName --region $Region `
    --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text
$ec2Id        = aws cloudformation describe-stacks --stack-name $StackName --region $Region `
    --query "Stacks[0].Outputs[?OutputKey=='EC2InstanceId'].OutputValue" --output text
$rdsHost      = aws cloudformation describe-stacks --stack-name $StackName --region $Region `
    --query "Stacks[0].Outputs[?OutputKey=='RDSHostname'].OutputValue" --output text
$lambdaName   = aws cloudformation describe-stacks --stack-name $StackName --region $Region `
    --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" --output text

Write-Host "  S3 bucket:       $bucketName" -ForegroundColor Green
Write-Host "  Lambda function: $lambdaName" -ForegroundColor Green
Write-Host "  EC2 instance:    $ec2Id" -ForegroundColor Green
Write-Host "  RDS endpoint:    $rdsHost" -ForegroundColor Green

# ── Enable S3 EventBridge ──────────────────────────────────────────────────
Write-Host ">>> Enabling S3 EventBridge notifications..." -ForegroundColor Cyan
aws s3api put-bucket-notification-configuration --bucket $bucketName `
    --notification-configuration '{"EventBridgeConfiguration": {}}' --region $Region
if ($LASTEXITCODE -eq 0) { Write-Host '  OK  EventBridge enabled' -ForegroundColor Green }

# ── Wait for EC2 ───────────────────────────────────────────────────────────
Write-Host ">>> Waiting for EC2 instance to boot and run user-data..." -ForegroundColor Cyan
Write-Host '  (Docker build + Rails migrations can take 5-10 minutes)' -ForegroundColor Yellow
aws ec2 wait instance-status-ok --instance-ids $ec2Id --region $Region
if ($LASTEXITCODE -eq 0) { Write-Host '  OK  EC2 is running' -ForegroundColor Green }

$publicIp = aws ec2 describe-instances --instance-ids $ec2Id --region $Region `
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '════════════════════════════════════════════════' -ForegroundColor Green
Write-Host '  DEPLOYMENT COMPLETE' -ForegroundColor Green
Write-Host '════════════════════════════════════════════════' -ForegroundColor Green
Write-Host ''
Write-Host "  Frontend:      http://$publicIp" -ForegroundColor Cyan
Write-Host "  Backend API:   http://$publicIp`:3000" -ForegroundColor Cyan
Write-Host "  RDS endpoint:  $rdsHost" -ForegroundColor Gray
Write-Host "  S3 bucket:     $bucketName" -ForegroundColor Gray
Write-Host "  Lambda:        $lambdaName" -ForegroundColor Gray
Write-Host ''
Write-Host "  SSM connect:" -ForegroundColor Yellow
Write-Host "    aws ssm start-session --target $ec2Id --region $Region"
Write-Host ''
Write-Host "  Tail deploy log:" -ForegroundColor Yellow
Write-Host "    tail -f /var/log/cloudvault-deploy.log"
Write-Host ''
Write-Host '  Note: Lambda WEBHOOK_URL is auto-configured by the EC2 user-data script.' -ForegroundColor Yellow
Write-Host "  Check 'docker ps' on the EC2 to confirm both containers are running." -ForegroundColor Yellow
Write-Host '════════════════════════════════════════════════' -ForegroundColor Green
