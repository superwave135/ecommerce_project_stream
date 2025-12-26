#!/bin/bash
# Teardown script for E-commerce Streaming Analytics Pipeline
# This script safely destroys all infrastructure to minimize costs

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}E-commerce Streaming Pipeline Teardown${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Warning message
echo -e "${RED}WARNING: This will destroy all infrastructure and data!${NC}"
echo ""
echo "This includes:"
echo "  - All Kinesis streams"
echo "  - All Lambda functions"
echo "  - Glue streaming job"
echo "  - RDS database (all data will be lost)"
echo "  - S3 bucket contents"
echo "  - VPC and networking"
echo ""

read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}Teardown cancelled. Infrastructure preserved.${NC}"
    exit 0
fi

echo ""
read -p "Enter environment to destroy (dev/staging/prod, default: dev): " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

read -sp "Enter RDS database password for confirmation: " DB_PASSWORD
echo ""

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Database password is required for teardown. Aborting.${NC}"
    exit 1
fi

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Step 1: Stop any running Glue jobs
echo ""
echo -e "${YELLOW}Step 1/4: Stopping active Glue jobs...${NC}"

GLUE_JOB_NAME=$(terraform output -raw glue_job_name 2>/dev/null || echo "")

if [ -n "$GLUE_JOB_NAME" ]; then
    # Get running job runs
    RUNNING_JOBS=$(aws glue get-job-runs --job-name "$GLUE_JOB_NAME" --query "JobRuns[?JobRunState=='RUNNING'].Id" --output text)
    
    if [ -n "$RUNNING_JOBS" ]; then
        echo "Stopping running Glue jobs..."
        for job_id in $RUNNING_JOBS; do
            aws glue batch-stop-job-run --job-name "$GLUE_JOB_NAME" --job-run-ids "$job_id"
            echo "  Stopped job run: $job_id"
        done
        echo -e "${GREEN}✓ Glue jobs stopped${NC}"
    else
        echo "  No running Glue jobs found"
    fi
else
    echo "  Glue job not found (may already be destroyed)"
fi

# Step 2: Disable EventBridge rules
echo ""
echo -e "${YELLOW}Step 2/4: Disabling EventBridge rules...${NC}"

DATA_GEN_RULE="ecommerce-streaming-${ENVIRONMENT}-data-generation"
aws events disable-rule --name "$DATA_GEN_RULE" 2>/dev/null && echo "  Disabled data generation rule" || echo "  Data generation rule not found"

echo -e "${GREEN}✓ EventBridge rules disabled${NC}"

# Step 3: Empty S3 bucket
echo ""
echo -e "${YELLOW}Step 3/4: Emptying S3 buckets...${NC}"

S3_BUCKET=$(terraform output -raw scripts_bucket_name 2>/dev/null || echo "")

if [ -n "$S3_BUCKET" ]; then
    echo "Emptying bucket: $S3_BUCKET"
    aws s3 rm "s3://${S3_BUCKET}" --recursive 2>/dev/null || echo "  Bucket already empty or doesn't exist"
    echo -e "${GREEN}✓ S3 bucket emptied${NC}"
else
    echo "  S3 bucket not found (may already be destroyed)"
fi

# Step 4: Destroy infrastructure
echo ""
echo -e "${YELLOW}Step 4/4: Destroying infrastructure with Terraform...${NC}"
echo ""

terraform destroy \
    -var-file="../config/${ENVIRONMENT}.tfvars" \
    -var="db_password=${DB_PASSWORD}" \
    -auto-approve

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Teardown Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All infrastructure has been destroyed."
echo "Estimated savings: ~$350/month vs keeping infrastructure running 24/7"
echo ""
echo "To deploy again, run: ./scripts/setup.sh"
echo ""
