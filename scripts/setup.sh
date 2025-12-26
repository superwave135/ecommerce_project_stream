#!/bin/bash
# Setup script for E-commerce Streaming Analytics Pipeline
# This script initializes and deploys the entire infrastructure

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}E-commerce Streaming Pipeline Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}Python 3 is required but not installed. Aborting.${NC}" >&2; exit 1; }

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Get user inputs
read -p "Enter AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "Enter environment (dev/staging/prod, default: dev): " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

read -sp "Enter RDS database password: " DB_PASSWORD
echo ""

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Database password is required. Aborting.${NC}"
    exit 1
fi

read -p "Enter GitHub repository URL: " GITHUB_REPO_URL

if [ -z "$GITHUB_REPO_URL" ]; then
    echo -e "${RED}GitHub repository URL is required. Aborting.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  AWS Region: $AWS_REGION"
echo "  Environment: $ENVIRONMENT"
echo "  GitHub Repo: $GITHUB_REPO_URL"
echo ""

read -p "Proceed with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi

# Navigate to project root
cd "$(dirname "$0")/.."

# Step 1: Package Lambda functions
echo ""
echo -e "${YELLOW}Step 1/5: Packaging Lambda functions...${NC}"

cd lambda/data_generator
pip install -r requirements.txt -t . --quiet
zip -r lambda_function.zip . -x "*.pyc" -x "__pycache__/*" >/dev/null
echo -e "${GREEN}✓ Data generator packaged${NC}"

cd ../orchestrator
pip install -r requirements.txt -t . --quiet
zip -r lambda_function.zip . -x "*.pyc" -x "__pycache__/*" >/dev/null
echo -e "${GREEN}✓ Orchestrator packaged${NC}"

cd ../..

# Step 2: Initialize Terraform
echo ""
echo -e "${YELLOW}Step 2/5: Initializing Terraform...${NC}"

cd terraform
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"

# Step 3: Validate Terraform
echo ""
echo -e "${YELLOW}Step 3/5: Validating Terraform configuration...${NC}"

terraform validate
echo -e "${GREEN}✓ Terraform configuration valid${NC}"

# Step 4: Plan infrastructure
echo ""
echo -e "${YELLOW}Step 4/5: Planning infrastructure deployment...${NC}"

terraform plan \
    -var-file="../config/${ENVIRONMENT}.tfvars" \
    -var="db_password=${DB_PASSWORD}" \
    -var="github_repo_url=${GITHUB_REPO_URL}" \
    -var="aws_region=${AWS_REGION}" \
    -out=tfplan

echo -e "${GREEN}✓ Terraform plan created${NC}"

# Step 5: Apply infrastructure
echo ""
echo -e "${YELLOW}Step 5/5: Deploying infrastructure...${NC}"

terraform apply tfplan

echo -e "${GREEN}✓ Infrastructure deployed${NC}"

# Get outputs
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
S3_BUCKET=$(terraform output -raw scripts_bucket_name)

cd ..

# Step 6: Upload Glue job script
echo ""
echo -e "${YELLOW}Uploading Glue job script to S3...${NC}"

aws s3 cp glue/jobs/stream_processor.py "s3://${S3_BUCKET}/glue-jobs/stream_processor.py"
echo -e "${GREEN}✓ Glue job script uploaded${NC}"

# Step 7: Initialize database
echo ""
echo -e "${YELLOW}Initializing database schema...${NC}"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo ""
echo "Please run the following commands to initialize the database:"
echo "  psql -h ${RDS_ENDPOINT} -U admin -d ecommerce_analytics -f postgres/schema/create_tables.sql"
echo "  psql -h ${RDS_ENDPOINT} -U admin -d ecommerce_analytics -f postgres/schema/seed_data.sql"
echo ""

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Initialize database (see commands above)"
echo "  2. Start the pipeline: ./scripts/start_pipeline.sh"
echo "  3. Monitor in CloudWatch dashboard"
echo "  4. When finished: ./scripts/teardown.sh"
echo ""
echo -e "${YELLOW}Remember to run teardown.sh after your session to minimize costs!${NC}"
echo ""
