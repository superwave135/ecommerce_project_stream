#!/bin/bash
# Deployment script for Lambda functions and Glue jobs
# Used for manual deployments and CI/CD

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Deploying E-commerce Streaming Pipeline Components${NC}"
echo ""

# Get component to deploy
COMPONENT=${1:-all}

# Navigate to project root
cd "$(dirname "$0")/.."

deploy_data_generator() {
    echo -e "${YELLOW}Deploying Data Generator Lambda...${NC}"
    cd lambda/data_generator
    
    # Clean up
    rm -f lambda_function.zip
    rm -rf package/
    
    # Install dependencies
    pip install -r requirements.txt -t package/ --quiet
    
    # Create deployment package
    cd package
    zip -r ../lambda_function.zip . >/dev/null
    cd ..
    zip -g lambda_function.zip lambda_function.py >/dev/null
    
    # Update Lambda function
    aws lambda update-function-code \
        --function-name ecommerce-streaming-dev-data-generator \
        --zip-file fileb://lambda_function.zip \
        --region ap-southeast-1
    
    echo -e "${GREEN}✓ Data Generator deployed${NC}"
    cd ../..
}

deploy_orchestrator() {
    echo -e "${YELLOW}Deploying Orchestrator Lambda...${NC}"
    cd lambda/orchestrator
    
    # Clean up
    rm -f lambda_function.zip
    rm -rf package/
    
    # Install dependencies
    pip install -r requirements.txt -t package/ --quiet
    
    # Create deployment package
    cd package
    zip -r ../lambda_function.zip . >/dev/null
    cd ..
    zip -g lambda_function.zip lambda_function.py >/dev/null
    
    # Update Lambda function
    aws lambda update-function-code \
        --function-name ecommerce-streaming-dev-orchestrator \
        --zip-file fileb://lambda_function.zip \
        --region ap-southeast-1
    
    echo -e "${GREEN}✓ Orchestrator deployed${NC}"
    cd ../..
}

deploy_glue() {
    echo -e "${YELLOW}Deploying Glue Streaming Job...${NC}"
    
    # Get S3 bucket name
    cd terraform
    S3_BUCKET=$(terraform output -raw scripts_bucket_name 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$S3_BUCKET" ]; then
        echo "Error: Cannot find S3 bucket. Is infrastructure deployed?"
        exit 1
    fi
    
    # Upload script
    aws s3 cp glue/jobs/stream_processor.py "s3://${S3_BUCKET}/glue-jobs/stream_processor.py"
    
    # Update Glue job
    aws glue update-job \
        --job-name ecommerce-streaming-dev-stream-processor \
        --job-update "Command={Name=gluestreaming,ScriptLocation=s3://${S3_BUCKET}/glue-jobs/stream_processor.py,PythonVersion=3}" \
        --region ap-southeast-1 2>/dev/null || echo "  (Glue job will be created by Terraform on first deploy)"
    
    echo -e "${GREEN}✓ Glue job deployed${NC}"
}

# Deploy based on component
case $COMPONENT in
    data-generator|data_generator|lambda-data)
        deploy_data_generator
        ;;
    orchestrator|lambda-orchestrator)
        deploy_orchestrator
        ;;
    glue|glue-job)
        deploy_glue
        ;;
    all)
        deploy_data_generator
        deploy_orchestrator
        deploy_glue
        ;;
    *)
        echo "Usage: $0 [data-generator|orchestrator|glue|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
