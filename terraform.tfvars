# Minimal tfvars — only values that require customisation per deployment.
# All other variables have sensible defaults defined in variables.tf.

project_name = "rds-platform"
environment  = "dev"

db_instance_class = "db.t4g.micro"
db_engine_version = "8.4"

rds_parameters = [
  {
    name         = "max_connections"
    value        = "100"
    apply_method = "immediate"
  }
]

enable_extended_support = false
