#!/bin/bash
# Validation script for E-commerce Streaming Analytics Pipeline
# Validates infrastructure deployment and health

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Infrastructure Validation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

cd "$(dirname "$0")/../terraform"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}✗ Terraform state not found. Infrastructure not deployed.${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking AWS resources...${NC}"
echo ""

# Function to check resource
check_resource() {
    local name=$1
    local check_cmd=$2
    
    if eval "$check_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $name${NC}"
        return 0
    else
        echo -e "${RED}✗ $name${NC}"
        return 1
    fi
}

ERRORS=0

# Check VPC
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
check_resource "VPC" "aws ec2 describe-vpcs --vpc-ids $VPC_ID" || ((ERRORS++))

# Check Kinesis Streams
CLICKS_STREAM=$(terraform output -raw clicks_stream_name 2>/dev/null || echo "")
check_resource "Kinesis - Clicks Stream" "aws kinesis describe-stream --stream-name $CLICKS_STREAM" || ((ERRORS++))

CHECKOUTS_STREAM=$(terraform output -raw checkouts_stream_name 2>/dev/null || echo "")
check_resource "Kinesis - Checkouts Stream" "aws kinesis describe-stream --stream-name $CHECKOUTS_STREAM" || ((ERRORS++))

# Check Lambda Functions
DATA_GEN=$(terraform output -raw data_generator_function_name 2>/dev/null || echo "")
check_resource "Lambda - Data Generator" "aws lambda get-function --function-name $DATA_GEN" || ((ERRORS++))

ORCH=$(terraform output -raw orchestrator_function_name 2>/dev/null || echo "")
check_resource "Lambda - Orchestrator" "aws lambda get-function --function-name $ORCH" || ((ERRORS++))

# Check Glue Job
GLUE_JOB=$(terraform output -raw glue_job_name 2>/dev/null || echo "")
check_resource "Glue - Stream Processor" "aws glue get-job --job-name $GLUE_JOB" || ((ERRORS++))

# Check RDS
RDS_ID="ecommerce-streaming-dev-postgres"
check_resource "RDS - PostgreSQL" "aws rds describe-db-instances --db-instance-identifier $RDS_ID" || ((ERRORS++))

# Check S3 Bucket
S3_BUCKET=$(terraform output -raw scripts_bucket_name 2>/dev/null || echo "")
check_resource "S3 - Scripts Bucket" "aws s3 ls s3://$S3_BUCKET" || ((ERRORS++))

# Check CodeBuild Projects
check_resource "CodeBuild - Data Generator" "aws codebuild batch-get-projects --names ecommerce-streaming-dev-data-generator-build" || ((ERRORS++))
check_resource "CodeBuild - Orchestrator" "aws codebuild batch-get-projects --names ecommerce-streaming-dev-orchestrator-build" || ((ERRORS++))
check_resource "CodeBuild - Glue Job" "aws codebuild batch-get-projects --names ecommerce-streaming-dev-glue-job-build" || ((ERRORS++))

echo ""
echo -e "${YELLOW}Checking pipeline status...${NC}"
echo ""

# Check if Glue job is running
GLUE_STATUS=$(aws glue get-job-runs --job-name "$GLUE_JOB" --max-results 1 --query 'JobRuns[0].JobRunState' --output text 2>/dev/null || echo "NONE")
if [ "$GLUE_STATUS" = "RUNNING" ]; then
    echo -e "${GREEN}✓ Glue job is running${NC}"
elif [ "$GLUE_STATUS" = "SUCCEEDED" ]; then
    echo -e "${YELLOW}! Glue job completed successfully (not currently running)${NC}"
else
    echo -e "${YELLOW}! Glue job is not running (Status: $GLUE_STATUS)${NC}"
fi

# Check EventBridge rule status
RULE_STATUS=$(aws events describe-rule --name "ecommerce-streaming-dev-data-generation" --query 'State' --output text 2>/dev/null || echo "UNKNOWN")
if [ "$RULE_STATUS" = "ENABLED" ]; then
    echo -e "${GREEN}✓ Data generation rule is enabled${NC}"
else
    echo -e "${YELLOW}! Data generation rule is disabled${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All resources validated successfully${NC}"
else
    echo -e "${RED}✗ $ERRORS resource(s) failed validation${NC}"
fi
echo -e "${GREEN}========================================${NC}"
echo ""

exit $ERRORS
