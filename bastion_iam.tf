# ─── BASTION IAM — SSM SESSION MANAGER ────────────────────────────────────────
# The EC2 instance requires an IAM role to call AWS APIs.
# AmazonSSMManagedInstanceCore grants the SSM agent the minimum permissions to:
#   - Register the instance with SSM
#   - Poll for session commands via ssmmessages endpoint
#   - Send session output back to the operator

data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${local.bastion_name}-role"
  description        = "Allows Bastion EC2 to use AWS SSM Session Manager"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json

  tags = {
    Name = "${local.bastion_name}-role"
  }
}

# AWS-managed policy — no custom policy needed, least-privilege for SSM.
resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile is the container that attaches an IAM role to an EC2 instance.
resource "aws_iam_instance_profile" "bastion" {
  name = "${local.bastion_name}-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name = "${local.bastion_name}-profile"
  }
}
