# terraform-aws-rds-mysql-platform

Terraform infrastructure for Amazon RDS MySQL 8.4 on AWS with a GitLab CI/CD pipeline.
Deploys a dedicated VPC, private RDS instance, and a Bastion host accessible exclusively via AWS SSM Session Manager.

---

> ⚠️ **For Learning & Testing Only**
>
> - Run `terraform destroy` immediately after testing — do not leave resources running
> - Use `db.t4g.micro` — smallest Free Tier eligible instance
> - Keep `deletion_protection = false` and `db_backup_retention_days = 0`
> - Keep `enable_extended_support = false` — enabling it incurs extra cost
> - Free tier applies to new AWS accounts only (first 12 months)
>
> **You are responsible for all AWS costs. Always check AWS Cost Explorer after testing.**

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  AWS Region: ap-south-1           VPC: 10.0.0.0/16                 │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Public Subnet: 10.0.1.0/24 (ap-south-1a)                   │  │
│  │                                                              │  │
│  │  ┌────────────────────┐      Route Table: 0.0.0.0/0 → IGW  │  │
│  │  │  Bastion (t3.micro)│                                     │  │
│  │  │  Amazon Linux 2023 │                                     │  │
│  │  │  SSM Session Mgr   │◄── Operator (aws ssm start-session) │  │
│  │  └─────────┬──────────┘                                     │  │
│  └────────────│─────────────────────────────────────────────────┘  │
│               │ Port 3306                                          │
│  ┌────────────│─────────────────────────────────────────────────┐  │
│  │  Private Subnets (No internet route — fully isolated)        │  │
│  │                                                              │  │
│  │  ┌─────────▼──────────────────────────────────────────────┐ │  │
│  │  │  RDS MySQL 8.4                                          │ │  │
│  │  │  ┌──────────────────────────────────────────────────┐  │ │  │
│  │  │  │  db.t4g.micro  /  ap-south-1a  /  10.0.10.0/24  │  │ │  │
│  │  │  └──────────────────────────────────────────────────┘  │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────┐   Internet Gateway (IGW)                     │
│  │  SSM Endpoints   │◄──────────────────────── Bastion HTTPS out   │
│  │  (AWS managed)   │                                              │
│  └──────────────────┘                                              │
└─────────────────────────────────────────────────────────────────────┘

Secrets: AWS SSM Parameter Store
  /rds-platform/dev/rds/master_password  (SecureString)
  /rds-platform/dev/rds/master_username  (String)
  /rds-platform/dev/rds/endpoint         (String)

State: S3 bucket (rds-platform-tfstate-*)
```

---

## Prerequisites

### Local Machine

| Tool | Version | Install |
|---|---|---|
| Terraform | >= 1.6.0 | `brew install terraform` |
| AWS CLI | >= 2.x | `brew install awscli` |
| Session Manager Plugin | latest | See below |

**Install AWS Session Manager Plugin (required for bastion access):**
```bash
# macOS
brew install --cask session-manager-plugin

# Verify
session-manager-plugin --version
```

### AWS Requirements

- IAM user/role with permissions: `ec2:*`, `rds:*`, `iam:*`, `ssm:*`, `s3:*` (on state bucket)
- S3 bucket created for Terraform state (see State Backend Setup)
- AWS CLI configured: `aws configure`

### GitLab Requirements

GitLab CI/CD variables configured (Settings → CI/CD → Variables):

| Variable | Description | Protected | Masked |
|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key | Yes | Yes |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key | Yes | Yes |
| `AWS_DEFAULT_REGION` | `ap-south-1` | Yes | No |
| `TF_STATE_BUCKET` | S3 bucket name | Yes | No |
| `TF_STATE_KEY` | `rds-platform/dev/terraform.tfstate` | Yes | No |
| `TF_STATE_REGION` | `ap-south-1` | Yes | No |

---

## State Backend Setup (One-Time)

Run these AWS CLI commands once to create the S3 state bucket:

```bash
BUCKET_NAME="rds-platform-tfstate-YOUR-INITIALS-XXXX"
REGION="ap-south-1"

# Create bucket
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

# Enable versioning (recover from state file corruption)
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Block all public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Bucket $BUCKET_NAME ready."
```

---

## Local Deployment

### First Time

```bash
# 1. Clone and enter project
cd terraform-aws-rds-mysql-platform

# 2. Initialise with S3 backend
terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="key=rds-platform/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"

# 3. Review the plan
terraform plan

# 4. Deploy
terraform apply
```

### Subsequent Runs

```bash
terraform plan   # review changes
terraform apply  # apply changes
```

---

## Connecting to the Bastion (SSM Session Manager)

No SSH key required. No port 22 open. Access is via AWS API only.

```bash
# 1. Get bastion instance ID from Terraform output
terraform output bastion_instance_id
# or use the ready-made command:
terraform output -raw ssm_connect_command

# 2. Open a shell session on the bastion
aws ssm start-session --target i-0xxxxxxxxxxxxxxxxx --region ap-south-1
```

**Requirements on your local machine:**
- AWS CLI configured with credentials that have `ssm:StartSession` permission
- Session Manager Plugin installed (see Prerequisites)

---

## Connecting to RDS MySQL

From inside the Bastion session:

```bash
# 1. Get connection details from SSM Parameter Store
ENDPOINT=$(aws ssm get-parameter \
  --name "/rds-platform/dev/rds/endpoint" \
  --region ap-south-1 \
  --query "Parameter.Value" --output text)

USERNAME=$(aws ssm get-parameter \
  --name "/rds-platform/dev/rds/master_username" \
  --region ap-south-1 \
  --query "Parameter.Value" --output text)

PASSWORD=$(aws ssm get-parameter \
  --name "/rds-platform/dev/rds/master_password" \
  --region ap-south-1 \
  --with-decryption \
  --query "Parameter.Value" --output text)

# 2. Connect
mysql -h "$ENDPOINT" -P 3306 -u "$USERNAME" -p"$PASSWORD"
```

---

## CI/CD Pipeline

| Stage | Job | Trigger | Branch |
|---|---|---|---|
| validate | `fmt_check` | Auto | All branches + MRs |
| validate | `validate` | Auto | All branches + MRs |
| plan | `plan` | Auto | All branches + MRs |
| apply | `apply` | **Manual** | Default branch only |
| destroy_plan | `destroy_plan` | **Manual** | Default branch only |
| destroy | `destroy` | **Manual** | Default branch only |

Pipeline confirmed working against the real AWS account.

### Pipeline Flow

```
Push to branch
     │
     ▼
[fmt_check] ──► [validate]
                    │
                    ▼
                 [plan] ──► artifact: tfplan (1 day expiry)
                               │
                          (manual click)
                               │
                               ▼
                           [apply] ──► reads tfplan artifact

--- destroy flow (independent, triggered separately) ---

                          (manual click)
                               │
                               ▼
                      [destroy_plan] ──► artifact: destroyplan (1 day expiry)
                                                    │
                                               (review logs)
                                                    │
                                               (manual click)
                                                    │
                                                    ▼
                                             [destroy] ──► reads destroyplan artifact
```

### CI Init Command

The pipeline runs `terraform init` as a single-line command to avoid GitLab YAML parser issues with multi-line `before_script` entries:

```bash
terraform init -reconfigure -input=false -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="key=${TF_STATE_KEY}" -backend-config="region=${TF_STATE_REGION}" -backend-config="encrypt=true"
```

### How to Trigger Apply

1. Push code to `main` branch
2. Wait for `validate` and `plan` stages to pass
3. In GitLab → CI/CD → Pipelines → click the pipeline
4. Click the **play button** next to the `apply` job

### How to Trigger Destroy

> **Warning:** This removes all AWS infrastructure. Cannot be undone. Always review the destroy plan before executing.

**Step 1 — Review the plan:**
1. Navigate to GitLab → CI/CD → Pipelines
2. Find the pipeline on `main` branch
3. Click the **play button** next to the `destroy_plan` job
4. Open the job logs and verify what will be destroyed

**Step 2 — Execute destroy:**
5. Click the **play button** next to the `destroy` job
6. The job applies the exact `destroyplan` artifact from step 1

The `destroyplan` artifact expires after 1 day. If it expires, re-trigger `destroy_plan` first.

---

## Important Notes

### Configurable Variables (terraform.tfvars)

| Variable | Default | Purpose |
|---|---|---|
| `db_engine_version` | `"8.4"` | MySQL engine version |
| `db_instance_class` | `"db.t4g.micro"` | RDS instance size. `db.t4g.micro` is Free Tier eligible |
| `rds_parameters` | `[{max_connections=100}]` | Parameter group settings — add/remove entries as needed |
| `enable_extended_support` | `false` | RDS extended support. Default off — enabling incurs extra cost |

### Instance Class

`db.t4g.micro` is the Free Tier eligible instance for RDS MySQL 8.4. Override in `terraform.tfvars` via `db_instance_class`.

### Password Management

The RDS master password is:
- Generated by Terraform (`random_password` resource)
- **Never** stored in `.tfvars`, environment variables, or CI/CD variables
- Stored in AWS SSM Parameter Store as `SecureString`
- Accessible only to IAM principals with `ssm:GetParameter` + KMS decrypt permission

### No SSH Access

The Bastion has **zero inbound security group rules**. There is no port 22. Access is exclusively via AWS SSM Session Manager — authenticated by IAM, logged by CloudTrail.

### No NAT Gateway

Private subnets have no default route and no NAT Gateway. RDS does not require internet access. Bastion reaches the internet via the IGW in the public subnet.

### RDS vs Aurora

This project uses standard RDS MySQL (single instance) instead of Aurora. Aurora MySQL is not available on AWS free-tier accounts. RDS MySQL provides equivalent functionality for dev/learning environments.

---

## File Reference

| File | Purpose |
|---|---|
| `versions.tf` | Terraform version, provider versions, S3 backend declaration |
| `provider.tf` | AWS provider config with default tags |
| `locals.tf` | Naming conventions and computed values |
| `variables.tf` | All input variables with types, descriptions, defaults |
| `terraform.tfvars` | Project name, environment, engine version, instance class, parameters, extended support flag |
| `vpc.tf` | VPC and Internet Gateway |
| `subnets.tf` | 3 subnets, 2 route tables, associations |
| `rds_security_group.tf` | RDS SG, inbound MySQL from Bastion only |
| `rds_instance.tf` | Password, SSM params, subnet group, parameter group, RDS instance |
| `bastion_security_group.tf` | Bastion SG, outbound HTTPS + MySQL only, zero inbound |
| `bastion_iam.tf` | IAM role, SSM policy attachment, instance profile |
| `bastion_instance.tf` | AMI data source, EC2 instance, user_data bootstrap |
| `outputs.tf` | All resource outputs including ready-to-run connect commands |
| `.gitlab-ci.yml` | 5-stage CI/CD pipeline (validate, plan, apply, destroy_plan, destroy) |

---

## Destroy (Clean Teardown)

```bash
# Via CLI
terraform destroy
```

Via CI/CD — two steps required (see How to Trigger Destroy above):
1. Click `destroy_plan` → review logs
2. Click `destroy` → executes the saved plan

All resources are configured for clean destroy:
- `skip_final_snapshot = true` (RDS)
- `deletion_protection = false` (RDS)
- No `prevent_destroy` lifecycle rules
- Dependency ordering is handled automatically by Terraform
