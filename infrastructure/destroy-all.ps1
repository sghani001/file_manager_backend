#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tear down the entire CloudVault File Manager stack on AWS.

.DESCRIPTION
    Prompts for the stack name and region, empties the S3 bucket
    (all versions), then deletes the CloudFormation stack. Cleans
    up Lambda CloudWatch logs at the end.

    Safe to commit to public GitHub — no hardcoded values.
#>

$ErrorActionPreference = 'Stop'
Write-Host '════════════════════════════════════════════════' -ForegroundColor Red
Write-Host '  CloudVault File Manager — DESTROY' -ForegroundColor Red
Write-Host '════════════════════════════════════════════════' -ForegroundColor Red
Write-Host ''

# ── Prerequisites ───────────────────────────────────────────────────────────
$aws = Get-Command aws -ErrorAction SilentlyContinue
if (-not $aws) { throw 'AWS CLI not found' }

aws sts get-caller-identity | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'AWS CLI not authenticated' }

# ── Read inputs ─────────────────────────────────────────────────────────────
$Region = Read-Host 'AWS region                              (e.g. us-east-1)'
while (-not $Region) { $Region = Read-Host '  AWS region (required)' }

$StackName = Read-Host 'CloudFormation stack name to destroy     (e.g. cloudvault-file-manager)'
while (-not $StackName) { $StackName = Read-Host '  Stack name (required)' }

# ── Check stack exists ─────────────────────────────────────────────────────
$stackExists = $false
try {
    $status = aws cloudformation describe-stacks --stack-name $StackName --region $Region `
        --query 'Stacks[0].StackStatus' --output text 2>$null
    if ($status) {
        $stackExists = $true
        Write-Host "  Found stack: $StackName (status: $status)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Stack '$StackName' not found in $Region" -ForegroundColor Yellow
}

# ── Get resources from outputs ─────────────────────────────────────────────
$bucketName   = if ($stackExists) { aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text 2>$null } else { $null }
$lambdaName   = if ($stackExists) { aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" --output text 2>$null } else { $null }
$ec2Id        = if ($stackExists) { aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='EC2InstanceId'].OutputValue" --output text 2>$null } else { $null }

if ($ec2Id -and $ec2Id -ne 'None' -and $ec2Id.Trim() -ne '') {
    Write-Host "  EC2 instance:   $ec2Id"
}
if ($bucketName -and $bucketName -ne 'None' -and $bucketName.Trim() -ne '') {
    Write-Host "  S3 bucket:      $bucketName"
}
if ($lambdaName -and $lambdaName -ne 'None' -and $lambdaName.Trim() -ne '') {
    Write-Host "  Lambda:         $lambdaName"
}

# If stack doesn't exist, ask for bucket name manually
if (-not $stackExists) {
    Write-Host ''
    Write-Host '  Stack not found — you can still clean up orphaned resources manually.' -ForegroundColor Yellow
    $manual = Read-Host '  Enter S3 bucket name to empty (or leave blank to skip)'
    if ($manual) { $bucketName = $manual }
    $manualLambda = Read-Host '  Enter Lambda function name for log cleanup (or leave blank to skip)'
    if ($manualLambda) { $lambdaName = $manualLambda }
}

# ── Confirmation ────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '  WARNING: This will PERMANENTLY DESTROY all resources.' -ForegroundColor Red
$confirm = Read-Host '  Type the stack name to confirm'
if ($confirm -ne $StackName) {
    Write-Host 'Aborted.' -ForegroundColor Yellow; exit 0
}

# ── Terminate EC2 early ────────────────────────────────────────────────────
if ($ec2Id -and $ec2Id -ne 'None' -and $ec2Id.Trim() -ne '') {
    Write-Host ">>> Terminating EC2 instance $ec2Id..." -ForegroundColor Cyan
    $state = aws ec2 describe-instances --instance-ids $ec2Id --region $Region `
        --query 'Reservations[0].Instances[0].State.Name' --output text 2>$null
    if ($state -eq 'running' -or $state -eq 'pending') {
        aws ec2 terminate-instances --instance-ids $ec2Id --region $Region | Out-Null
        Write-Host '  OK  Termination initiated' -ForegroundColor Green
    } else {
        Write-Host '  Instance already stopped or terminated' -ForegroundColor Yellow
    }
}

# ── Empty S3 bucket ─────────────────────────────────────────────────────────
if ($bucketName -and $bucketName -ne 'None' -and $bucketName.Trim() -ne '') {
    Write-Host ">>> Emptying S3 bucket: $bucketName..." -ForegroundColor Cyan

    # Delete all versions
    Write-Host '  Deleting object versions...' -ForegroundColor Gray
    $versions = aws s3api list-object-versions --bucket $bucketName --region $Region --output json 2>$null
    if ($versions) {
        $v = $versions | ConvertFrom-Json
        if ($v.Versions) {
            $keys = $v.Versions | ForEach-Object { @{Key=$_.Key; VersionId=$_.VersionId} }
            for ($i = 0; $i -lt $keys.Count; $i += 1000) {
                $batch = @{Objects=$keys[$i..([Math]::Min($i+999, $keys.Count-1))]}
                aws s3api delete-objects --bucket $bucketName --delete ($batch | ConvertTo-Json -Compress) --region $Region | Out-Null
            }
        }
        # Delete delete markers
        if ($v.DeleteMarkers) {
            $markers = $v.DeleteMarkers | ForEach-Object { @{Key=$_.Key; VersionId=$_.VersionId} }
            for ($i = 0; $i -lt $markers.Count; $i += 1000) {
                $batch = @{Objects=$markers[$i..([Math]::Min($i+999, $markers.Count-1))]}
                aws s3api delete-objects --bucket $bucketName --delete ($batch | ConvertTo-Json -Compress) --region $Region | Out-Null
            }
        }
    }
    # Force delete bucket
    aws s3 rb "s3://$bucketName" --force --region $Region 2>$null
    Write-Host '  OK  S3 bucket emptied and deleted' -ForegroundColor Green

    # Wait a moment for S3 deletion to propagate
    Start-Sleep -Seconds 5
}

# ── Delete CloudFormation stack ─────────────────────────────────────────────
if ($stackExists) {
    Write-Host ">>> Deleting CloudFormation stack '$StackName'..." -ForegroundColor Cyan
    aws cloudformation delete-stack --stack-name $StackName --region $Region
    Write-Host '  OK  Deletion initiated, waiting for completion...' -ForegroundColor Green

    aws cloudformation wait stack-delete-complete --stack-name $StackName --region $Region
    if ($LASTEXITCODE -eq 0) {
        Write-Host '  OK  Stack deleted successfully' -ForegroundColor Green
    } else {
        Write-Host '  !! Stack may still be deleting (check AWS Console)' -ForegroundColor Yellow
    }
} else {
    Write-Host '  Skipping stack deletion (not found)' -ForegroundColor Yellow
}

# ── Delete Lambda CloudWatch logs ──────────────────────────────────────────
if ($lambdaName -and $lambdaName -ne 'None' -and $lambdaName.Trim() -ne '') {
    $logGroup = "/aws/lambda/$lambdaName"
    Write-Host ">>> Deleting Lambda log group: $logGroup..." -ForegroundColor Cyan
    aws logs delete-log-group --log-group-name $logGroup --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '  OK  Log group deleted' -ForegroundColor Green
    } else {
        Write-Host '  Log group not found or already deleted' -ForegroundColor Yellow
    }
}

# ── Done ────────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '════════════════════════════════════════════════' -ForegroundColor Green
Write-Host '  TEARDOWN COMPLETE' -ForegroundColor Green
Write-Host '════════════════════════════════════════════════' -ForegroundColor Green
Write-Host ''
Write-Host '  Verify in AWS Console that no resources remain:' -ForegroundColor Yellow
Write-Host '    - CloudFormation -> Stacks (should be deleted)'
Write-Host '    - S3 -> Buckets (should be deleted)'
Write-Host '    - EC2 -> Instances (should be terminated)'
Write-Host '    - RDS -> Databases (should be deleted)'
Write-Host '    - Lambda -> Functions (should be deleted)'
Write-Host '    - CloudWatch -> Log groups (should be deleted)'
Write-Host ''
