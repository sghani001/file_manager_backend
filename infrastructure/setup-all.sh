#!/usr/bin/env bash
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  CloudVault File Manager — Provisioner${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ── Prerequisites ───────────────────────────────────────────────────────────
echo -e "${CYAN}>>> Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo "ERROR: AWS CLI not found"; exit 1; }

aws sts get-caller-identity --output json >/dev/null 2>&1 || { echo "ERROR: AWS CLI not authenticated. Run 'aws configure' first."; exit 1; }

TEMPLATE="$(cd "$(dirname "$0")" && pwd)/cloudvault-full-stack.yaml"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template not found at $TEMPLATE"
    exit 1
fi
echo -e "  ${GREEN}OK${NC} Prerequisites met"
echo ""

# ── Read inputs ─────────────────────────────────────────────────────────────
prompt_required() {
    local label="$1" val="" secret="${2:-}"
    while [ -z "$val" ]; do
        if [ "$secret" = "true" ]; then
            read -s -p "  $label: " val
            echo ""
        else
            read -p "  $label: " val
        fi
        [ -z "$val" ] && echo -e "  ${YELLOW}(this value is required)${NC}"
    done
    echo "$val"
}

prompt_optional() {
    local label="$1" default="$2" val
    read -p "  $label [$default]: " val
    echo "${val:-$default}"
}

echo -e "${CYAN}>>> Enter configuration values${NC}"
echo ""

REGION=$(prompt_required "AWS region                         (e.g. us-east-1)")
STACK_NAME=$(prompt_required "CloudFormation stack name           (e.g. cloudvault-file-manager)")
BUCKET_NAME=$(prompt_required "S3 bucket name (globally unique)    (e.g. cloudvault-uploads-YOURNAME)")
GITHUB_BACKEND=$(prompt_required "GitHub backend repo URL             (e.g. https://github.com/you/backend.git)")
GITHUB_FRONTEND=$(prompt_required "GitHub frontend repo URL            (e.g. https://github.com/you/frontend.git)")
GIT_BRANCH=$(prompt_optional "Git branch to deploy" "main")
DB_USERNAME=$(prompt_optional "RDS database username" "postgres")
DB_PASSWORD=$(prompt_required "RDS master password" "true")
RAILS_MASTER_KEY=$(prompt_required "Rails master.key" "true")
JWT_SECRET=$(prompt_required "JWT secret" "true")
LAMBDA_WEBHOOK_SECRET=$(prompt_required "Lambda webhook secret" "true")
INSTANCE_TYPE=$(prompt_optional "EC2 instance type" "t3.medium")

echo ""
echo -e "${CYAN}>>> Configuration summary:${NC}"
echo "  Region:              $REGION"
echo "  Stack name:          $STACK_NAME"
echo "  S3 bucket:           $BUCKET_NAME"
echo "  Backend repo:        $GITHUB_BACKEND"
echo "  Frontend repo:       $GITHUB_FRONTEND"
echo "  Git branch:          $GIT_BRANCH"
echo "  DB username:         $DB_USERNAME"
echo "  DB password:         ********"
echo "  EC2 instance type:   $INSTANCE_TYPE"
echo ""

read -p "Proceed with deployment? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${YELLOW}Aborted.${NC}"; exit 0
fi

# ── Deploy CloudFormation ───────────────────────────────────────────────────
echo -e "${CYAN}>>> Deploying stack '$STACK_NAME' to $REGION (10-15 minutes)...${NC}"

aws cloudformation deploy \
    --template-file "$TEMPLATE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        BucketName="$BUCKET_NAME" \
        DBUsername="$DB_USERNAME" \
        DBPassword="$DB_PASSWORD" \
        RailsMasterKey="$RAILS_MASTER_KEY" \
        JWTSecret="$JWT_SECRET" \
        LambdaWebhookSecret="$LAMBDA_WEBHOOK_SECRET" \
        InstanceType="$INSTANCE_TYPE" \
        GithubBackendRepo="$GITHUB_BACKEND" \
        GithubFrontendRepo="$GITHUB_FRONTEND" \
        GitBranch="$GIT_BRANCH" \
    --capabilities CAPABILITY_IAM \
    --region "$REGION"

if [ $? -ne 0 ]; then
    echo "ERROR: Stack deployment failed"
    exit 1
fi
echo -e "  ${GREEN}OK${NC} Stack creation initiated"

# ── Wait for stack ──────────────────────────────────────────────────────────
echo -e "${CYAN}>>> Waiting for stack creation to complete...${NC}"
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
if [ $? -ne 0 ]; then
    aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].StackStatus'
    echo "ERROR: Stack did not reach CREATE_COMPLETE"
    exit 1
fi
echo -e "  ${GREEN}OK${NC} Stack creation complete"

# ── Get outputs ─────────────────────────────────────────────────────────────
BUCKET_NAME_OUT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text)
EC2_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='EC2InstanceId'].OutputValue" --output text)
RDS_HOST=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='RDSHostname'].OutputValue" --output text)
LAMBDA_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" --output text)

echo -e "  ${GREEN}S3 bucket:       $BUCKET_NAME_OUT${NC}"
echo -e "  ${GREEN}Lambda function: $LAMBDA_NAME${NC}"
echo -e "  ${GREEN}EC2 instance:    $EC2_ID${NC}"
echo -e "  ${GREEN}RDS endpoint:    $RDS_HOST${NC}"

# ── Enable S3 EventBridge ───────────────────────────────────────────────────
echo -e "${CYAN}>>> Enabling S3 EventBridge notifications...${NC}"
aws s3api put-bucket-notification-configuration --bucket "$BUCKET_NAME_OUT" \
    --notification-configuration '{"EventBridgeConfiguration": {}}' --region "$REGION"
echo -e "  ${GREEN}OK${NC} EventBridge enabled"

# ── Wait for EC2 ────────────────────────────────────────────────────────────
echo -e "${CYAN}>>> Waiting for EC2 instance to boot (Docker build + migrations = 5-10 min)...${NC}"
aws ec2 wait instance-status-ok --instance-ids "$EC2_ID" --region "$REGION"
echo -e "  ${GREEN}OK${NC} EC2 is running"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$EC2_ID" --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOYMENT COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  ${CYAN}Frontend:      http://$PUBLIC_IP${NC}"
echo -e "  ${CYAN}Backend API:   http://$PUBLIC_IP:3000${NC}"
echo -e "  RDS endpoint:  $RDS_HOST"
echo -e "  S3 bucket:     $BUCKET_NAME_OUT"
echo -e "  Lambda:        $LAMBDA_NAME"
echo ""
echo -e "  ${YELLOW}SSM connect:${NC}"
echo -e "    aws ssm start-session --target $EC2_ID --region $REGION"
echo ""
echo -e "  ${YELLOW}Tail deploy log:${NC}"
echo -e "    tail -f /var/log/cloudvault-deploy.log"
echo ""
echo -e "  ${YELLOW}Note: Lambda WEBHOOK_URL is auto-configured by user-data.${NC}"
echo -e "  ${YELLOW}Check 'docker ps' on EC2 to confirm both containers run.${NC}"
echo -e "${GREEN}========================================${NC}"
