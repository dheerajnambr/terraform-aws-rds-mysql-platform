# ─── AMI DATA SOURCE ───────────────────────────────────────────────────────────
# Resolves the latest Amazon Linux 2023 AMI at plan time.
# Using most_recent = true ensures new deployments pick up patched AMIs.
# The lifecycle ignore_changes on the instance prevents in-place AMI replacements
# — existing bastion is only replaced when explicitly recreated.

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ─── BASTION EC2 INSTANCE ──────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.bastion_instance_type

  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true

  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # Bootstrap script: installs MySQL 8.0 community client on first boot.
  # Steps:
  #   1. Import MySQL 8 GPG key (prevents tampered package installation)
  #   2. Install MySQL community repository definition RPM
  #   3. Install mysql-community-client from community repo only (scoped install)
  user_data = <<-EOT
    #!/bin/bash
    set -ex
    rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
    dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
    dnf install -y --disablerepo='*' --enablerepo='mysql80-community' mysql-community-client
  EOT

  # Do not re-run user_data if the script changes — avoids instance replacement.
  user_data_replace_on_change = false

  lifecycle {
    # Do not replace instance when a newer AMI is published — controlled upgrade.
    ignore_changes = [ami]
  }

  tags = {
    Name = local.bastion_name
  }
}
