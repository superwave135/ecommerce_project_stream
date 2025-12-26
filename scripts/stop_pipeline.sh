#!/bin/bash
# Stop the E-commerce Streaming Pipeline

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping E-commerce Streaming Pipeline${NC}"
echo ""

cd "$(dirname "$0")/../terraform"

# Get resource names
ORCHESTRATOR=$(terraform output -raw orchestrator_function_name 2>/dev/null || echo "")
DATA_GEN_RULE="ecommerce-streaming-dev-data-generation"

# Disable data generation first
echo -e "${YELLOW}Disabling data generation...${NC}"
aws events disable-rule --name "$DATA_GEN_RULE" --region ap-southeast-1
echo -e "${GREEN}✓ Data generation disabled${NC}"
echo ""

# Wait a moment for pending invocations
echo "Waiting for pending Lambda invocations to complete..."
sleep 5

# Stop Glue job
echo -e "${YELLOW}Stopping Glue streaming job...${NC}"
echo '{"action": "stop"}' > /tmp/payload.json
aws lambda invoke \
    --function-name "$ORCHESTRATOR" \
    --cli-binary-format raw-in-base64-out \
    --payload file:///tmp/payload.json \
    /tmp/response.json \
    --region ap-southeast-1
mv /tmp/response.json response.json
rm -f /tmp/payload.json

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pipeline Stopped Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  - Check final data: Run queries from postgres/queries/sample_queries.sql"
echo "  - Destroy infrastructure to save costs: ./scripts/teardown.sh"
echo ""
