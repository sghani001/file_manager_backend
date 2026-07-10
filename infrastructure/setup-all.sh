#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  CloudVault File Manager — Provisioner${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ── Prerequisites ───────────────────────────────────────────────────────────
echo -e "${CYAN}>>> Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo "ERROR: AWS CLI not found"; exit 1; }
aws sts get-caller-identity --output json >/dev/null 2>&1 || { echo "ERROR: AWS CLI not authenticated"; exit 1; }

if pwd -W >/dev/null 2>&1; then
    TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd -W)"
else
    TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
TEMPLATE="$TEMPLATE_DIR/cloudvault-full-stack.yaml"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template not found at $TEMPLATE"
    exit 1
fi
echo -e "  ${GREEN}OK${NC}"
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
        [ -z "$val" ] && echo -e "  ${YELLOW}(required)${NC}"
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
echo -e "${CYAN}>>> Summary:${NC}"
echo "  Region:              $REGION"
echo "  Stack:               $STACK_NAME"
echo "  S3 bucket:           $BUCKET_NAME"
echo "  Backend repo:        $GITHUB_BACKEND"
echo "  Frontend repo:       $GITHUB_FRONTEND"
echo "  Branch:              $GIT_BRANCH"
echo "  DB username:         $DB_USERNAME"
echo "  DB password:         ********"
echo "  EC2 type:            $INSTANCE_TYPE"
echo ""

read -p "Proceed? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${YELLOW}Aborted.${NC}"; exit 0
fi

# ── Write parameters to temp file ──────────────────────────────────────────
PARAM_FILE=$(mktemp)
cat > "$PARAM_FILE" <<EOF
[
    {"ParameterKey":"BucketName","ParameterValue":"$BUCKET_NAME"},
    {"ParameterKey":"DBUsername","ParameterValue":"$DB_USERNAME"},
    {"ParameterKey":"DBPassword","ParameterValue":"$DB_PASSWORD"},
    {"ParameterKey":"RailsMasterKey","ParameterValue":"$RAILS_MASTER_KEY"},
    {"ParameterKey":"JWTSecret","ParameterValue":"$JWT_SECRET"},
    {"ParameterKey":"LambdaWebhookSecret","ParameterValue":"$LAMBDA_WEBHOOK_SECRET"},
    {"ParameterKey":"InstanceType","ParameterValue":"$INSTANCE_TYPE"},
    {"ParameterKey":"GithubBackendRepo","ParameterValue":"$GITHUB_BACKEND"},
    {"ParameterKey":"GithubFrontendRepo","ParameterValue":"$GITHUB_FRONTEND"},
    {"ParameterKey":"GitBranch","ParameterValue":"$GIT_BRANCH"}
]
EOF

# Build file:// URI (convert Windows backslashes to forward slashes)
TEMPLATE_URI="file:///$(echo "$TEMPLATE" | sed 's|\\|/|g')"

# ── Create stack ───────────────────────────────────────────────────────────
echo -e "${CYAN}>>> Creating stack '$STACK_NAME' in $REGION (15-20 min)...${NC}"
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "$TEMPLATE_URI" \
    --parameters "file://$PARAM_FILE" \
    --capabilities CAPABILITY_IAM \
    --region "$REGION"

if [ $? -ne 0 ]; then
    rm -f "$PARAM_FILE"
    echo "ERROR: Stack creation failed"
    exit 1
fi
echo -e "  ${GREEN}OK${NC} Creation initiated"

# ── Wait for stack ──────────────────────────────────────────────────────────
echo -e "${CYAN}>>> Waiting for stack creation...${NC}"
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
if [ $? -ne 0 ]; then
    STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
        --query 'Stacks[0].StackStatus' --output text)
    echo "ERROR: Stack status: $STATUS"
    aws cloudformation describe-stack-events --stack-name "$STACK_NAME" --region "$REGION" \
        --query 'StackEvents[0].ResourceStatusReason' --output text
    rm -f "$PARAM_FILE"
    exit 1
fi
rm -f "$PARAM_FILE"
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
echo -e "  ${GREEN}OK${NC}"

# ── Wait for EC2 ────────────────────────────────────────────────────────────
echo -e "${CYAN}>>> Waiting for EC2 to boot (Docker + migrations = 5-10 min)...${NC}"
aws ec2 wait instance-status-ok --instance-ids "$EC2_ID" --region "$REGION"
echo -e "  ${GREEN}OK${NC} EC2 running"

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
echo -e "  ${YELLOW}SSM: aws ssm start-session --target $EC2_ID --region $REGION${NC}"
echo -e "  ${YELLOW}Log: tail -f /var/log/cloudvault-deploy.log${NC}"
echo -e "  ${YELLOW}Lambda WEBHOOK_URL is auto-configured by EC2 user-data${NC}"
echo -e "${GREEN}========================================${NC}"
