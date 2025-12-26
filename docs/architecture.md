# Architecture Documentation

## Overview

The E-commerce Streaming Analytics Pipeline is a real-time data processing system that performs first-click attribution analysis on e-commerce events.

## Architecture Layers

### 1. Data Generation Layer
- **Component**: Lambda Function (Data Generator)
- **Trigger**: EventBridge (every 5 minutes)
- **Function**: Generates synthetic click and checkout events
- **Output**: Writes to two Kinesis streams

### 2. Streaming Layer
- **Component**: Amazon Kinesis Data Streams
- **Streams**: 
  - `ecommerce-streaming-dev-clicks`: Click events
  - `ecommerce-streaming-dev-checkouts`: Checkout events
- **Mode**: On-Demand (cost-optimized)
- **Retention**: 24 hours

### 3. Processing Layer
- **Component**: AWS Glue Streaming Job
- **Engine**: Apache Spark (PySpark)
- **Workers**: 2 DPUs (G.1X)
- **Processing Logic**:
  - Stream-stream join between clicks and checkouts
  - First-click attribution (ROW_NUMBER window function)
  - 1-hour attribution window
  - 5-minute watermark for late data

### 4. Storage Layer
- **Component**: Amazon RDS PostgreSQL
- **Instance**: db.t3.micro
- **Tables**:
  - `raw_clicks`: All click events
  - `raw_checkouts`: All checkout events
  - `attributed_checkouts`: Attribution results
  - `users`: User dimension table

### 5. Orchestration Layer
- **Component**: Lambda Function (Orchestrator) + EventBridge
- **Functions**:
  - Start Glue streaming job
  - Stop Glue streaming job
  - Check job status
- **Scheduling**: Manual or scheduled via EventBridge

### 6. Monitoring Layer
- **Component**: CloudWatch
- **Features**:
  - Custom dashboard
  - Log aggregation
  - Metric alarms
  - Performance monitoring

### 7. CI/CD Layer
- **Component**: AWS CodeBuild + GitHub Webhooks
- **Projects**:
  - Data Generator deployment
  - Orchestrator deployment
  - Glue job deployment
- **Trigger**: Git push to main branch

## Data Flow

```
1. EventBridge (Schedule) → Lambda (Data Generator)
2. Lambda → Kinesis Streams (Clicks + Checkouts)
3. Kinesis Streams → Glue Streaming Job
4. Glue Job → PostgreSQL (RDS)
5. PostgreSQL → Analytics Queries
```

## Attribution Logic

The pipeline implements **first-click attribution**:

1. **Join Window**: 1 hour before checkout
2. **Attribution Rule**: First click within the window gets credit
3. **Implementation**:
   ```sql
   ROW_NUMBER() OVER (
     PARTITION BY checkout_id 
     ORDER BY click_timestamp ASC
   ) = 1
   ```

## Network Architecture

- **VPC**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24
- **Private Subnets**: 10.0.10.0/24, 10.0.11.0/24
- **Database Subnets**: 10.0.20.0/24, 10.0.21.0/24
- **NAT Gateway**: For private subnet internet access
- **VPC Endpoints**: S3, Glue (cost optimization)

## Security

- **Encryption at Rest**: KMS (Kinesis), AES-256 (S3, RDS)
- **Encryption in Transit**: TLS for all connections
- **Network Isolation**: Database in private subnets
- **IAM**: Least privilege roles
- **Security Groups**: Restricted access

## Scalability

- **Kinesis**: On-Demand mode auto-scales
- **Glue**: Can increase DPUs and workers
- **RDS**: Can upgrade instance class
- **Lambda**: Auto-scales to 1000 concurrent executions

## High Availability

- **Multi-AZ**: RDS, subnets across 2 AZs
- **Managed Services**: Lambda, Kinesis, Glue are highly available
- **Automatic Failover**: RDS supports multi-AZ failover

## Cost Optimization

- **Strategy**: `terraform destroy` after each session
- **Savings**: 99.3% vs 24/7 operation
- **On-Demand**: Kinesis scales to zero when not in use
- **VPC Endpoints**: Reduce data transfer costs

## Performance

- **Latency**: Sub-second stream processing
- **Throughput**: Scales with Glue DPUs
- **Checkpointing**: S3-based for fault tolerance
- **Watermarking**: 5-minute window for late data

## Monitoring Metrics

- Kinesis: Incoming records, iterator age, throttled records
- Lambda: Invocations, errors, duration
- Glue: Job run state, execution time, records processed
- RDS: CPU, connections, storage, throughput

## Future Enhancements

- [ ] Multi-touch attribution models
- [ ] Real-time dashboard with QuickSight
- [ ] ML-based anomaly detection
- [ ] Data quality validation
- [ ] A/B testing framework
- [ ] Customer segmentation
