#!/bin/bash
# Start the E-commerce Streaming Pipeline

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting E-commerce Streaming Pipeline${NC}"
echo ""

cd "$(dirname "$0")/../terraform"

# Get resource names
ORCHESTRATOR=$(terraform output -raw orchestrator_function_name 2>/dev/null || echo "")
DATA_GEN_RULE="ecommerce-streaming-dev-data-generation"

# Start Glue job
echo -e "${YELLOW}Starting Glue streaming job...${NC}"
aws lambda invoke \
    --function-name "$ORCHESTRATOR" \
    --payload '{"action": "start"}' \
    response.json \
    --region ap-southeast-1

cat response.json | python3 -m json.tool
rm response.json
echo ""

# Enable data generation
echo -e "${YELLOW}Enabling data generation...${NC}"
aws events enable-rule --name "$DATA_GEN_RULE" --region ap-southeast-1
echo -e "${GREEN}✓ Data generation enabled${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pipeline Started Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Monitor the pipeline:"
echo "  - CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-1#dashboards:name=ecommerce-streaming-dev-dashboard"
echo "  - Glue Job: https://console.aws.amazon.com/glue/home?region=ap-southeast-1#etl:tab=jobs"
echo ""
echo "To stop the pipeline: ./scripts/stop_pipeline.sh"
echo ""
