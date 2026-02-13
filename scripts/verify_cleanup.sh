#!/bin/bash
echo "🔍 Checking for remaining de_project_stream resources..."
echo ""

REGION="ap-southeast-1"
PROJECT_PREFIX="ecommerce-streaming-dev"

# 1. VPC and Networking
echo "1️⃣ VPC & Networking:"
aws ec2 describe-vpcs \
  --region $REGION \
  --filters "Name=tag:Name,Values=*ecommerce*" \
  --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
  --output table

aws ec2 describe-nat-gateways \
  --region $REGION \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].[NatGatewayId,State]' \
  --output table

aws ec2 describe-internet-gateways \
  --region $REGION \
  --filters "Name=tag:Name,Values=*ecommerce*" \
  --query 'InternetGateways[*].[InternetGatewayId]' \
  --output table

# 2. RDS Database
echo ""
echo "2️⃣ RDS Database:"
aws rds describe-db-instances \
  --region $REGION \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `ecommerce`)].[DBInstanceIdentifier,DBInstanceStatus]' \
  --output table

# 3. Kinesis Streams
echo ""
echo "3️⃣ Kinesis Streams:"
aws kinesis list-streams \
  --region $REGION \
  --output json | jq -r '.StreamNames[] | select(contains("ecommerce"))'

# 4. Lambda Functions
echo ""
echo "4️⃣ Lambda Functions:"
aws lambda list-functions \
  --region $REGION \
  --query 'Functions[?contains(FunctionName, `ecommerce`)].[FunctionName,Runtime]' \
  --output table

# 5. Glue Jobs & Connections
echo ""
echo "5️⃣ Glue Jobs:"
aws glue get-jobs \
  --region $REGION \
  --query 'Jobs[?contains(Name, `ecommerce`)].[Name]' \
  --output table

echo ""
echo "6️⃣ Glue Connections:"
aws glue get-connections \
  --region $REGION \
  --query 'ConnectionList[?contains(Name, `ecommerce`)].[Name]' \
  --output table

# 7. S3 Buckets
echo ""
echo "7️⃣ S3 Buckets:"
aws s3 ls | grep ecommerce

# 8. IAM Roles
echo ""
echo "8️⃣ IAM Roles:"
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `ecommerce`)].[RoleName,CreateDate]' \
  --output table

# 9. Security Groups
echo ""
echo "9️⃣ Security Groups:"
aws ec2 describe-security-groups \
  --region $REGION \
  --filters "Name=group-name,Values=*ecommerce*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table

# 10. VPC Endpoints
echo ""
echo "🔟 VPC Endpoints:"
aws ec2 describe-vpc-endpoints \
  --region $REGION \
  --filters "Name=tag:Name,Values=*ecommerce*" \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
  --output table

# 11. EventBridge Rules
echo ""
echo "1️⃣1️⃣ EventBridge Rules:"
aws events list-rules \
  --region $REGION \
  --query 'Rules[?contains(Name, `ecommerce`)].[Name,State]' \
  --output table

# 12. CloudWatch Log Groups
echo ""
echo "1️⃣2️⃣ CloudWatch Log Groups:"
aws logs describe-log-groups \
  --region $REGION \
  --query 'logGroups[?contains(logGroupName, `ecommerce`)].[logGroupName]' \
  --output table

# 13. EC2 Instances
echo ""
echo "1️⃣3️⃣ EC2 Instances:"
aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Name,Values=*ecommerce*" "Name=instance-state-name,Values=running,stopped,stopping" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table

# 14. Network Interfaces
echo ""
echo "1️⃣4️⃣ Network Interfaces:"
aws ec2 describe-network-interfaces \
  --region $REGION \
  --filters "Name=description,Values=*ecommerce*" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' \
  --output table

echo ""
echo "✅ Verification complete!"
echo ""
echo "💡 If all sections show empty tables, all resources are deleted!"