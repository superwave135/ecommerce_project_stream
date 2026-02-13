# E-commerce Streaming Analytics Pipeline

A real-time click attribution analytics pipeline built on AWS, performing first-click attribution analysis on streaming e-commerce data.

## 📋 Project Overview

This project implements a complete streaming data pipeline that:
- Generates synthetic e-commerce click and checkout events
- Streams events through AWS Kinesis
- Processes streams in real-time using AWS Glue with PySpark
- Performs first-click attribution analysis
- Stores results in PostgreSQL (RDS)
- Provides automated CI/CD deployment via CodeBuild

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Cloud Architecture                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐   │
│  │ EventBridge  │─────>│  Lambda      │─────>│   Kinesis    │   │
│  │  (Schedule)  │      │  (Data Gen)  │      │   Streams    │   │
│  └──────────────┘      └──────────────┘      │ - Clicks     │   │
│                                              │ - Checkouts  │   │
│                                              └──────┬───────┘   │
│                                                     │           │
│                                                     v           │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐   │
│  │ EventBridge  │─────>│  Lambda      │      │     Glue     │   │
│  │ (Start/Stop) │      │(Orchestrator)│─────>│  Streaming   │   │
│  └──────────────┘      └──────────────┘      │     Job      │   │
│                                              └──────┬───────┘   │
│                                                     │           │
│                                                     v           │
│                                               ┌──────────────┐  │
│                                               │  PostgreSQL  │  │
│                                               │    (RDS)     │  │
│                                               └──────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │               CI/CD (CodeBuild + GitHub)                 │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.0
- Python 3.11+
- Git
- GitHub account (for CI/CD)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/de_project_stream.git
   cd de_project_stream
   ```

2. **Configure AWS credentials**
   ```bash
   aws configure
   ```

3. **Update configuration**
   - Edit `config/dev.tfvars` with your settings
   - Set `github_repo_url` to your repository
   - Set `db_password` (will be provided during apply)

4. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

5. **Deploy infrastructure**
   ```bash
   terraform plan -var-file="../config/dev.tfvars" -var="db_password=YourSecurePassword123!"
   terraform apply -var-file="../config/dev.tfvars" -var="db_password=YourSecurePassword123!"
   ```

6. **Package and upload Lambda functions**
   ```bash
   cd ../scripts
   ./deploy.sh
   ```

7. **Upload Glue job script**
   ```bash
   aws s3 cp ../glue/jobs/stream_processor.py s3://ecommerce-streaming-scripts-YOUR_ACCOUNT_ID/glue-jobs/
   ```

8. **Initialize database schema**
   ```bash
   # Connect to RDS instance
   psql -h YOUR_RDS_ENDPOINT -U admin -d ecommerce_analytics -f ../postgres/schema/create_tables.sql
   psql -h YOUR_RDS_ENDPOINT -U admin -d ecommerce_analytics -f ../postgres/schema/seed_data.sql
   ```

## 🎯 Usage

### Starting the Pipeline

1. **Start Glue streaming job**
   ```bash
   aws lambda invoke --function-name ecommerce-streaming-dev-orchestrator \
     --payload '{"action": "start"}' response.json
   ```

2. **Enable data generation (EventBridge rule)**
   ```bash
   aws events enable-rule --name ecommerce-streaming-dev-data-generation
   ```

### Monitoring

- **CloudWatch Dashboard**: Navigate to CloudWatch > Dashboards > `ecommerce-streaming-dev-dashboard`
- **Glue Job Status**: Check AWS Glue console or use orchestrator Lambda
- **Database Queries**: Run analytical queries from `postgres/queries/sample_queries.sql`

### Stopping the Pipeline

1. **Stop Glue job**
   ```bash
   aws lambda invoke --function-name ecommerce-streaming-dev-orchestrator \
     --payload '{"action": "stop"}' response.json
   ```

2. **Disable data generation**
   ```bash
   aws events disable-rule --name ecommerce-streaming-dev-data-generation
   ```

3. **Destroy infrastructure (to minimize costs)**
   ```bash
   cd terraform
   terraform destroy -var-file="../config/dev.tfvars" -var="db_password=YourSecurePassword123!"
   ```

## 💰 Cost Optimization

### Estimated Costs (1-hour session)

| Service | Cost |
|---------|------|
| Kinesis On-Demand | $0.015 - $0.04 |
| Glue Streaming (2 DPU × 1 hour) | $0.44 |
| Lambda | $0.001 - $0.003 |
| RDS (db.t3.micro) | $0.016 |
| **Total per session** | **~$0.50 - $0.60** |

### Cost-Saving Strategy

**Use `terraform destroy` after each learning session!**

- Monthly cost if infrastructure runs 24/7: **~$360**
- Monthly cost with destroy strategy (4 sessions/month): **~$2.40**
- **Savings: 99.3%**

## 📁 Project Structure

```
de_project_stream/
├── lambda/                      # Lambda functions
│   ├── data_generator/          # Event generation
│   └── orchestrator/            # Job orchestration
├── glue/                        # Glue streaming job
│   ├── jobs/                    # PySpark scripts
│   └── scripts/                 # Helper scripts
├── postgres/                    # Database scripts
│   ├── schema/                  # Table definitions
│   └── queries/                 # Analytical queries
├── terraform/                   # Infrastructure as Code
├── monitoring/                  # CloudWatch configs
├── eventbridge/                 # Event rules
├── scripts/                     # Utility scripts
├── docs/                        # Documentation
└── config/                      # Configuration files
```

## 🔄 CI/CD Pipeline

The project uses AWS CodeBuild with GitHub webhooks for automated deployments:

- **Data Generator Lambda**: Triggered on changes to `lambda/data_generator/`
- **Orchestrator Lambda**: Triggered on changes to `lambda/orchestrator/`
- **Glue Job**: Triggered on changes to `glue/jobs/`

### Setting Up CI/CD

1. Push code to GitHub
2. CodeBuild projects automatically deploy on push to main branch
3. Monitor builds in AWS CodeBuild console

## 📊 Analytics Queries

Sample queries are available in `postgres/queries/sample_queries.sql`:

- Revenue attribution by traffic source
- Time to purchase analysis
- Product category performance
- Device type conversion analysis
- Hourly revenue trends
- Customer segment performance
- Top converting products
- Click-to-conversion funnel
- Multi-touch attribution analysis
- Real-time streaming metrics

## 🛠️ Development

### Local Testing

1. **Test Lambda functions locally**
   ```bash
   cd lambda/data_generator
   python lambda_function.py
   ```

2. **Validate Glue job syntax**
   ```bash
   cd glue/jobs
   python -m py_compile stream_processor.py
   ```

3. **Test database schema**
   ```bash
   psql -h localhost -U postgres -f postgres/schema/create_tables.sql
   ```

### Adding New Features

1. Make changes to code
2. Update relevant buildspec.yml if needed
3. Commit and push to GitHub
4. CodeBuild automatically deploys changes

## 🔒 Security Best Practices

- ✅ All data encrypted at rest (KMS)
- ✅ All data encrypted in transit (TLS)
- ✅ Database in private subnet
- ✅ IAM roles with least privilege
- ✅ VPC endpoints for cost and security
- ✅ Security groups restrict access
- ✅ Secrets not committed to Git

## 📖 Documentation

- [Architecture Details](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)
- [Cost Analysis](docs/cost_analysis.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is for educational purposes.

## 🙋‍♂️ Support

For issues or questions:
- Open a GitHub issue
- Review documentation in `docs/` folder

## ✨ Features

- ✅ Real-time streaming data processing
- ✅ First-click attribution analysis
- ✅ Automated CI/CD pipeline
- ✅ Cost-optimized architecture
- ✅ Comprehensive monitoring
- ✅ Production-ready code
- ✅ Fully documented

---

**Built with ❤️ and coffee by GeekyTan**

------------------------------------------------------------------------------------------------------
For Future Reference - Here's Your "View Tables" Command:
Save this in your notes or README. Anytime you want to view the data:

# 1. Make sure script is uploaded
aws s3 cp scripts/query_tables.py s3://ecommerce-streaming-dev-scripts-881786084229/glue/query_tables.py

# 2. Create temp job
aws glue create-job \
  --name ecommerce-query-temp \
  --role arn:aws:iam::881786084229:role/ecommerce-streaming-dev-glue-job-role \
  --command '{"Name": "glueetl", "ScriptLocation": "s3://ecommerce-streaming-dev-scripts-881786084229/glue/query_tables.py", "PythonVersion": "3"}' \
  --glue-version "4.0" \
  --number-of-workers 2 \
  --worker-type "G.1X" \
  --connections Connections=["ecommerce-streaming-dev-postgres-connection"] \
  --region ap-southeast-1

# 3. Run it
aws glue start-job-run --job-name ecommerce-query-temp --region ap-southeast-1

# 4. Wait 2 min, then view results
sleep 120
aws logs tail /aws-glue/jobs/output --since 3m --region ap-southeast-1 --format short

# 5. Delete when done
aws glue delete-job --job-name ecommerce-query-temp --region ap-southeast-1

------------------------------------------------------------------------------------------------------
