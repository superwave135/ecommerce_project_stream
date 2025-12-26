# Deployment Guide

## Prerequisites

### Required Tools
- AWS CLI v2.x
- Terraform >= 1.0
- Python 3.11+
- Git
- PostgreSQL client (psql)

### AWS Requirements
- AWS Account with admin permissions
- Configured AWS credentials (`aws configure`)
- GitHub account for CI/CD

## Step-by-Step Deployment

### 1. Clone Repository
```bash
git clone https://github.com/YOUR_USERNAME/de_project_stream.git
cd de_project_stream
```

### 2. Configure Variables

Edit `config/dev.tfvars`:
```hcl
github_repo_url = "https://github.com/YOUR_USERNAME/de_project_stream"
aws_region      = "us-east-1"
db_username     = "admin"
# db_password will be provided during apply
```

### 3. Run Setup Script

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

The setup script will:
- Package Lambda functions
- Initialize Terraform
- Deploy infrastructure
- Upload Glue job script

### 4. Initialize Database

```bash
# Get RDS endpoint from Terraform output
cd terraform
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Connect and run schema
psql -h $RDS_ENDPOINT -U admin -d ecommerce_analytics -f ../postgres/schema/create_tables.sql

# Load seed data
psql -h $RDS_ENDPOINT -U admin -d ecommerce_analytics -f ../postgres/schema/seed_data.sql
```

### 5. Verify Deployment

```bash
./scripts/validate.sh
```

Expected output: All resources validated successfully

## Starting the Pipeline

### Manual Start
```bash
./scripts/start_pipeline.sh
```

This will:
1. Start Glue streaming job
2. Enable EventBridge data generation rule

### Check Status
```bash
# Glue job status
aws glue get-job-runs --job-name ecommerce-streaming-dev-stream-processor --max-results 1

# EventBridge rule status
aws events describe-rule --name ecommerce-streaming-dev-data-generation
```

## Monitoring

### CloudWatch Dashboard
- Navigate to: CloudWatch > Dashboards > `ecommerce-streaming-dev-dashboard`
- Metrics: Kinesis records, Lambda invocations, RDS connections

### View Logs
```bash
# Glue job logs
aws logs tail /aws-glue/jobs/ecommerce-streaming-dev-stream-processor --follow

# Lambda logs
aws logs tail /aws/lambda/ecommerce-streaming-dev-data-generator --follow
```

### Query Database
```bash
psql -h $RDS_ENDPOINT -U admin -d ecommerce_analytics

# Run analytics queries
\i postgres/queries/sample_queries.sql
```

## Stopping the Pipeline

### Manual Stop
```bash
./scripts/stop_pipeline.sh
```

This will:
1. Disable EventBridge data generation
2. Stop Glue streaming job
3. Wait for graceful shutdown

## Infrastructure Teardown

⚠️ **Important**: Run teardown after each session to minimize costs!

```bash
./scripts/teardown.sh
```

Confirmation required. Will destroy:
- All AWS resources
- All data in RDS
- S3 bucket contents

## Troubleshooting

### Issue: Glue Job Fails to Start

**Symptoms**: Job run state = FAILED immediately

**Solutions**:
1. Check Glue job script exists in S3
2. Verify IAM role has required permissions
3. Check VPC security groups allow Glue ENI creation
4. Review CloudWatch logs for errors

```bash
# Check if script exists
aws s3 ls s3://ecommerce-streaming-scripts-ACCOUNT_ID/glue-jobs/

# Verify IAM role
aws iam get-role --role-name ecommerce-streaming-dev-glue-job-role
```

### Issue: Lambda Cannot Write to Kinesis

**Symptoms**: Lambda errors, no data in Kinesis

**Solutions**:
1. Verify IAM role has `kinesis:PutRecord` permission
2. Check KMS key policy allows Lambda to use it
3. Confirm Kinesis stream exists

```bash
# Test Lambda function
aws lambda invoke --function-name ecommerce-streaming-dev-data-generator response.json
cat response.json
```

### Issue: Database Connection Fails

**Symptoms**: Cannot connect to RDS, timeout errors

**Solutions**:
1. Check security group allows PostgreSQL port (5432)
2. Verify database subnet group configured correctly
3. Confirm RDS instance is in "available" state
4. Check VPC route tables

```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier ecommerce-streaming-dev-postgres

# Test connection
nc -zv $RDS_ENDPOINT 5432
```

### Issue: CodeBuild Fails

**Symptoms**: Build fails, deployment unsuccessful

**Solutions**:
1. Check GitHub webhook configuration
2. Verify CodeBuild IAM role permissions
3. Review buildspec.yml syntax
4. Check CodeBuild logs

```bash
# Get recent build
aws codebuild list-builds-for-project --project-name ecommerce-streaming-dev-data-generator-build

# View build logs
aws logs get-log-events --log-group-name /aws/codebuild/ecommerce-streaming-dev-data-generator-build --log-stream-name <stream-name>
```

### Issue: High Costs

**Symptoms**: Unexpected AWS charges

**Solutions**:
1. Verify `terraform destroy` was run
2. Check for orphaned resources
3. Review CloudWatch billing alarms
4. Ensure EventBridge rules are disabled

```bash
# List all resources by tag
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=ecommerce-streaming
```

## CI/CD Setup

### Configure GitHub Webhooks

1. Go to GitHub repository settings
2. Navigate to Webhooks
3. Add webhook URLs from CodeBuild console
4. Configure for push events
5. Test webhook delivery

### Trigger Deployments

Deployments trigger automatically on push to main:

```bash
# Make changes
git add lambda/data_generator/lambda_function.py
git commit -m "Update data generator logic"
git push origin main

# CodeBuild automatically deploys
```

### Manual Deployment

```bash
./scripts/deploy.sh [component]

# Examples:
./scripts/deploy.sh data-generator
./scripts/deploy.sh orchestrator
./scripts/deploy.sh glue
./scripts/deploy.sh all
```

## Best Practices

1. **Always use teardown**: Run `./scripts/teardown.sh` after each session
2. **Test locally first**: Validate Lambda functions locally before deploying
3. **Monitor costs**: Set up AWS billing alarms
4. **Use Git**: Version control all changes
5. **Check logs**: Review CloudWatch logs for errors
6. **Validate deployment**: Run `./scripts/validate.sh` after deployment
7. **Database backups**: RDS automated backups enabled (1-day retention)

## Production Deployment

For production environments:

1. Create `config/prod.tfvars`
2. Enable multi-AZ RDS
3. Increase backup retention
4. Set `db_skip_final_snapshot = false`
5. Enable deletion protection
6. Configure SNS alerts
7. Use private GitHub repository
8. Store secrets in AWS Secrets Manager
9. Enable enhanced monitoring
10. Configure auto-scaling

```hcl
# config/prod.tfvars
environment                = "prod"
db_instance_class          = "db.t3.small"
db_backup_retention_period = 7
db_skip_final_snapshot     = false
enable_detailed_monitoring = true
```

## Rollback Procedure

If deployment fails:

1. **Check Terraform state**:
   ```bash
   cd terraform
   terraform show
   ```

2. **Rollback to previous state**:
   ```bash
   terraform state pull > backup.tfstate
   # Fix issues
   terraform apply
   ```

3. **Restore Lambda code**:
   ```bash
   git checkout HEAD~1 lambda/data_generator/lambda_function.py
   ./scripts/deploy.sh data-generator
   ```

## Support

- Check [Architecture Documentation](architecture.md)
- Review [Cost Analysis](cost_analysis.md)
- Open GitHub issue for bugs
- Check CloudWatch logs for errors
