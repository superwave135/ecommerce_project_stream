# Cost Analysis

## Cost Breakdown (Per 1-Hour Session)

### Compute Services

| Service | Configuration | Hourly Rate | 1-Hour Cost |
|---------|--------------|-------------|-------------|
| AWS Glue | 2 DPU (G.1X) | $0.44/DPU-hour | $0.88 |
| Lambda (Data Gen) | 256MB, ~12 invocations | $0.00001667/invocation | $0.0002 |
| Lambda (Orchestrator) | 128MB, ~2 invocations | $0.00000833/invocation | $0.00002 |

### Storage Services

| Service | Configuration | Hourly Rate | 1-Hour Cost |
|---------|--------------|-------------|-------------|
| RDS PostgreSQL | db.t3.micro | $0.016/hour | $0.016 |
| S3 (Scripts) | ~100MB storage | $0.000003/GB-hour | $0.0003 |

### Streaming Services

| Service | Configuration | Hourly Rate | 1-Hour Cost |
|---------|--------------|-------------|-------------|
| Kinesis On-Demand | ~1,200 records | $0.015/million PUTs | $0.00002 |

### Networking

| Service | Configuration | Hourly Rate | 1-Hour Cost |
|---------|--------------|-------------|-------------|
| NAT Gateway | Data transfer | $0.045/hour + $0.045/GB | $0.05 |
| VPC Endpoints | 2 endpoints | $0.01/hour/endpoint | $0.02 |

### **Total Cost Per 1-Hour Session: ~$0.97**

## Cost Comparison: Destroy vs. Keep Running

### Scenario 1: Terraform Destroy After Each Session
- **Sessions per month**: 4 (weekly learning sessions)
- **Hours per session**: 1
- **Monthly cost**: 4 × $0.97 = **$3.88**
- **Annual cost**: $3.88 × 12 = **$46.56**

### Scenario 2: Keep Infrastructure Running 24/7
- **Hours per month**: 730
- **Monthly cost**: 730 × $0.97 = **$708.10**
- **Annual cost**: $708.10 × 12 = **$8,497.20**

### **Savings with Destroy Strategy: 99.5%**

## Detailed Monthly Costs (24/7 Operation)

### Compute (Monthly)
```
Glue:        2 DPU × $0.44 × 730 hours = $642.40
Lambda (Gen): 12/hour × 730 × $0.00001667 = $0.15
Lambda (Orch): 2/hour × 730 × $0.00000833 = $0.01
                                    Total = $642.56
```

### Storage (Monthly)
```
RDS:         $0.016 × 730 hours = $11.68
S3:          100MB × $0.023/GB = $0.0023
                          Total = $11.68
```

### Streaming (Monthly)
```
Kinesis:     ~876,000 records × $0.015/million = $0.01
```

### Networking (Monthly)
```
NAT Gateway: $0.045 × 730 + data transfer = $32.85 + ~$5 = $37.85
VPC Endpoints: 2 × $0.01 × 730 = $14.60
                                          Total = $52.45
```

### **Total Monthly (24/7): $708.10**

## Cost Optimization Strategies

### 1. Terraform Destroy (Recommended)
✅ **Saves 99.5%** of costs
```bash
# After each session
./scripts/teardown.sh
```

### 2. Reduce Glue DPUs
```hcl
# terraform/variables.tf
glue_max_capacity = 1.0  # Instead of 2.0
```
**Savings**: 50% on Glue costs

### 3. Use Spot Instances for Development
Not applicable for managed services, but consider for EC2-based alternatives

### 4. Optimize Kinesis Usage
Already using On-Demand mode (optimal for sporadic workloads)

### 5. RDS Instance Downsizing
```hcl
db_instance_class = "db.t3.micro"  # Already minimal
```

### 6. S3 Lifecycle Policies
Already configured:
- Archive to Glacier after 90 days
- Delete after 365 days

### 7. CloudWatch Log Retention
```hcl
log_retention_days = 7  # Instead of 30
```
**Savings**: ~75% on log storage

## Cost Monitoring

### Set Up Billing Alarms

1. **Create SNS Topic**:
```bash
aws sns create-topic --name billing-alerts
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts --protocol email --notification-endpoint your@email.com
```

2. **Create Billing Alarm**:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name monthly-cost-alarm \
  --alarm-description "Alert if monthly costs exceed $10" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 10.0 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts
```

### Monitor Costs in AWS Console

1. Navigate to AWS Cost Explorer
2. Filter by tag: `Project=ecommerce-streaming`
3. View daily/monthly trends
4. Identify cost anomalies

### Use AWS Budgets

```bash
# Set monthly budget
aws budgets create-budget \
  --account-id ACCOUNT_ID \
  --budget file://budget.json
```

## Hidden Costs to Watch

### 1. NAT Gateway Data Transfer
- **Cost**: $0.045/GB
- **Mitigation**: Use VPC endpoints where possible
- **Monitoring**: CloudWatch metrics for NAT Gateway bytes

### 2. Kinesis Extended Retention
- Default: 24 hours (included)
- Extended: $0.02/shard-hour
- **Recommendation**: Keep at 24 hours for learning

### 3. RDS Storage Growth
- **Cost**: $0.115/GB-month
- **Mitigation**: Regular data cleanup
- **Monitoring**: CloudWatch RDS storage metrics

### 4. CloudWatch Logs
- **Cost**: $0.50/GB ingested
- **Mitigation**: 7-day retention, filter verbose logs
- **Monitoring**: Log group size

### 5. Data Transfer Out
- **Cost**: $0.09/GB (to internet)
- **Impact**: Minimal for this project
- **Monitoring**: CloudWatch data transfer metrics

## Cost by Component (Monthly, 24/7)

```
┌─────────────────────────────────────┐
│ Component Cost Breakdown            │
├─────────────────────────────────────┤
│ Glue (91%)           $642.40        │
│ NAT Gateway (5%)      $37.85        │
│ VPC Endpoints (2%)    $14.60        │
│ RDS (2%)              $11.68        │
│ Other (<1%)            $1.57        │
├─────────────────────────────────────┤
│ TOTAL:               $708.10        │
└─────────────────────────────────────┘
```

## Recommendations by Usage Pattern

### Learning/Development (Recommended Strategy)
- **Pattern**: 1-hour sessions, 1x per week
- **Strategy**: Terraform destroy after each session
- **Monthly Cost**: ~$3.88
- **Best For**: Learning, testing, development

### Active Development
- **Pattern**: Daily sessions, 1-2 hours
- **Strategy**: Keep infrastructure, destroy on weekends
- **Monthly Cost**: ~$50-100
- **Best For**: Active project development

### Production/Always-On
- **Pattern**: 24/7 operation
- **Strategy**: Optimize instance sizes, use reserved capacity
- **Monthly Cost**: ~$400-600 (with optimizations)
- **Best For**: Production workloads

## Free Tier Benefits

First 12 months:
- ✅ Lambda: 1M requests/month (covers our usage)
- ✅ RDS: 750 hours/month db.t2.micro (we use t3.micro)
- ❌ Glue: No free tier
- ❌ Kinesis: No free tier

**Note**: Even with free tier, Glue is the major cost driver.

## ROI Analysis

### Learning Investment
- **Project cost (4 sessions)**: $3.88
- **Alternative**: AWS Training course ($300-500)
- **Savings**: 99% cheaper, hands-on experience

### Production Value
- **Development time saved**: 40+ hours (pre-built infrastructure)
- **Best practices included**: Worth $1000+ in consulting
- **Reusable components**: Applicable to other projects

## Summary

| Metric | Value |
|--------|-------|
| Cost per 1-hour session | $0.97 |
| Cost per month (4 sessions) | $3.88 |
| Cost per month (24/7) | $708.10 |
| Savings with destroy | 99.5% |
| Most expensive component | AWS Glue (91%) |
| Recommended strategy | Terraform destroy |

**Bottom Line**: Use `./scripts/teardown.sh` after each session to keep costs under $5/month!
