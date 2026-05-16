# Project: terraform-aws-rds-mysql-platform

Terraform infrastructure for Amazon RDS MySQL 8.4 on AWS (ap-south-1) with GitLab CI/CD.

## Quick Context

- Region: `ap-south-1` (Mumbai)
- State bucket: `rds-platform-tfstate-dinfratech-bucket1` (pre-exists, manually created)
- Two git remotes: `gitlab` (primary CI/CD) and `origin` (GitHub mirror)
- Always push to BOTH remotes after merging to main

## Local Terraform Init

```bash
terraform init \
  -backend-config="bucket=rds-platform-tfstate-dinfratech-bucket1" \
  -backend-config="key=rds-platform/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"
```

## Hard Constraints — Never Violate

| Rule | Reason |
|---|---|
| `db.t4g.micro` for RDS MySQL (Free Tier eligible) | Aurora MySQL is not available on free-tier accounts; use standard RDS |
| Zero inbound rules on bastion SG | SSM-only access, no SSH from internet |
| No DynamoDB lock table | Single operator, manual apply gate — not needed |
| No NAT Gateway | Cost (~$33/month). RDS needs no internet. |
| No credentials in tfvars or CI/CD vars | Passwords go in SSM Parameter Store only |
| SG rules as separate resources | Circular dependency: bastion ↔ rds SG. Use `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule`, never inline |

## GitLab CI — Single-Line Init Required

The `terraform init` in `.gitlab-ci.yml` `before_script` **must be a single line**.
Multi-line continuation with `-backend-config` flags causes GitLab YAML parse error:
`script config should be a string or a nested array of strings up to 10 levels deep`

Correct pattern:
```yaml
before_script:
  - terraform init -reconfigure -input=false -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="key=${TF_STATE_KEY}" -backend-config="region=${TF_STATE_REGION}" -backend-config="encrypt=true"
```

## Git Workflow

```bash
# Feature work
git checkout -b fix/description
# ... make changes ...
git add <files>
git commit -m "type: description"

# Merge to main
git checkout main
git merge fix/description --no-edit

# Push both remotes
git push gitlab main
git push origin main
```

## File Map

| File | What it owns |
|---|---|
| `versions.tf` | TF version, provider versions, S3 backend stub |
| `provider.tf` | AWS provider, default_tags |
| `locals.tf` | name_prefix and all computed names |
| `variables.tf` | All input variables |
| `terraform.tfvars` | project_name, environment, db config, rds_parameters, extended support flag |
| `vpc.tf` | VPC + IGW |
| `subnets.tf` | 3 subnets, 2 route tables, associations |
| `rds_security_group.tf` | RDS SG + ingress rule from bastion |
| `rds_instance.tf` | Password, SSM params, subnet group, param group, RDS instance |
| `bastion_security_group.tf` | Bastion SG + 3 egress rules |
| `bastion_iam.tf` | IAM role, SSM policy, instance profile |
| `bastion_instance.tf` | AMI data source, EC2 instance |
| `outputs.tf` | Outputs including ssm_connect_command, mysql_connect_command |
| `aws-rds-gitlab-cicd-guide.md` | Full technical doc + setup guide (AWS IAM, GitHub, GitLab CI/CD, variables) |
| `README.md` | Quick-start, architecture diagram, deployment steps, file reference |

## Post-Apply: Connect to Bastion

```bash
# Get instance ID
terraform output bastion_instance_id

# Open shell
aws ssm start-session --target i-XXXXXXXXXXXXXXXXX --region ap-south-1
```

Requires: AWS CLI + Session Manager Plugin + IAM `ssm:StartSession` permission.
