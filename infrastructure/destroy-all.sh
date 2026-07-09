#!/usr/bin/env bash
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}  CloudVault File Manager — DESTROY${NC}"
echo -e "${RED}========================================${NC}"
echo ""

# ── Prerequisites ───────────────────────────────────────────────────────────
command -v aws >/dev/null 2>&1 || { echo "ERROR: AWS CLI not found"; exit 1; }
aws sts get-caller-identity --output json >/dev/null 2>&1 || { echo "ERROR: AWS CLI not authenticated"; exit 1; }

# ── Read inputs ─────────────────────────────────────────────────────────────
read -p "AWS region                              (e.g. us-east-1): " REGION
while [ -z "$REGION" ]; do
    read -p "  AWS region (required): " REGION
done

read -p "CloudFormation stack name to destroy     (e.g. cloudvault-file-manager): " STACK_NAME
while [ -z "$STACK_NAME" ]; do
    read -p "  Stack name (required): " STACK_NAME
done

# ── Check stack exists ──────────────────────────────────────────────────────
STACK_EXISTS=false
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null || true)
if [ -n "$STACK_STATUS" ]; then
    STACK_EXISTS=true
    echo -e "  ${GREEN}Found stack: $STACK_NAME (status: $STACK_STATUS)${NC}"
else
    echo -e "  ${YELLOW}Stack '$STACK_NAME' not found in $REGION${NC}"
fi

# ── Get resources from outputs ──────────────────────────────────────────────
BUCKET_NAME=""; LAMBDA_NAME=""; EC2_ID=""
if [ "$STACK_EXISTS" = true ]; then
    BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text 2>/dev/null || true)
    LAMBDA_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" --output text 2>/dev/null || true)
    EC2_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='EC2InstanceId'].OutputValue" --output text 2>/dev/null || true)
fi

# If stack doesn't exist, ask for orphaned resources
if [ "$STACK_EXISTS" = false ]; then
    echo ""
    echo -e "  ${YELLOW}Stack not found — you can still clean up orphaned resources manually.${NC}"
    read -p "  Enter S3 bucket name to empty (or leave blank to skip): " MANUAL_BUCKET
    [ -n "$MANUAL_BUCKET" ] && BUCKET_NAME="$MANUAL_BUCKET"
    read -p "  Enter Lambda function name for log cleanup (or leave blank to skip): " MANUAL_LAMBDA
    [ -n "$MANUAL_LAMBDA" ] && LAMBDA_NAME="$MANUAL_LAMBDA"
fi

echo ""
echo -e "  ${RED}WARNING: This will PERMANENTLY DESTROY all resources.${NC}"
read -p "  Type the stack name to confirm: " CONFIRM
if [ "$CONFIRM" != "$STACK_NAME" ]; then
    echo -e "${YELLOW}Aborted.${NC}"; exit 0
fi

# ── Terminate EC2 early ─────────────────────────────────────────────────────
if [ -n "$EC2_ID" ] && [ "$EC2_ID" != "None" ]; then
    echo -e "${CYAN}>>> Terminating EC2 instance $EC2_ID...${NC}"
    STATE=$(aws ec2 describe-instances --instance-ids "$EC2_ID" --region "$REGION" \
        --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || true)
    if [ "$STATE" = "running" ] || [ "$STATE" = "pending" ]; then
        aws ec2 terminate-instances --instance-ids "$EC2_ID" --region "$REGION" >/dev/null
        echo -e "  ${GREEN}OK${NC} Termination initiated"
    else
        echo -e "  ${YELLOW}Instance already stopped or terminated${NC}"
    fi
fi

# ── Empty S3 bucket ─────────────────────────────────────────────────────────
if [ -n "$BUCKET_NAME" ] && [ "$BUCKET_NAME" != "None" ]; then
    echo -e "${CYAN}>>> Emptying S3 bucket: $BUCKET_NAME...${NC}"
    aws s3 rb "s3://$BUCKET_NAME" --force --region "$REGION"
    echo -e "  ${GREEN}OK${NC} S3 bucket emptied and deleted"
    sleep 5
fi

# ── Delete CloudFormation stack ─────────────────────────────────────────────
if [ "$STACK_EXISTS" = true ]; then
    echo -e "${CYAN}>>> Deleting CloudFormation stack '$STACK_NAME'...${NC}"
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
    echo -e "  ${GREEN}OK${NC} Deletion initiated, waiting for completion..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC} Stack deleted successfully"
    else
        echo -e "  ${YELLOW}!! Stack may still be deleting (check AWS Console)${NC}"
    fi
else
    echo -e "  ${YELLOW}Skipping stack deletion (not found)${NC}"
fi

# ── Delete Lambda CloudWatch logs ──────────────────────────────────────────
if [ -n "$LAMBDA_NAME" ] && [ "$LAMBDA_NAME" != "None" ]; then
    LOG_GROUP="/aws/lambda/$LAMBDA_NAME"
    echo -e "${CYAN}>>> Deleting Lambda log group: $LOG_GROUP...${NC}"
    aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
    echo -e "  ${GREEN}OK${NC} Log group deleted"
fi

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  TEARDOWN COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  ${YELLOW}Verify in AWS Console that no resources remain:${NC}"
echo "    - CloudFormation -> Stacks (should be deleted)"
echo "    - S3 -> Buckets (should be deleted)"
echo "    - EC2 -> Instances (should be terminated)"
echo "    - RDS -> Databases (should be deleted)"
echo "    - Lambda -> Functions (should be deleted)"
echo "    - CloudWatch -> Log groups (should be deleted)"
echo ""
