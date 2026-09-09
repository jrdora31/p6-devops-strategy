data "aws_ami" "debian" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Interroge AWS dès le plan afin de refuser un type d'instance incompatible
# avant l'étape manuelle et coûteuse de création de l'EC2.
data "aws_ec2_instance_type" "selected" {
  instance_type = var.instance_type
}

locals {
  selected_ami_id = coalesce(var.ami_id, try(data.aws_ami.debian[0].id, null))
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name_prefix}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "cloudwatch_agent" {
  count = var.cloudwatch_agent_enabled ? 1 : 0

  statement {
    sid       = "PublishMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    sid    = "PublishPocLogs"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:${var.cloudwatch_log_group_prefix}*"]
  }

  statement {
    sid    = "PublishPocLogStreams"
    effect = "Allow"
    actions = [
      "logs:DescribeLogStreams",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:${var.cloudwatch_log_group_prefix}*:log-stream:*"
    ]
  }

  statement {
    sid       = "ReadInstanceTags"
    effect    = "Allow"
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch_agent" {
  count  = var.cloudwatch_agent_enabled ? 1 : 0
  name   = "${var.name_prefix}-cloudwatch-agent"
  role   = aws_iam_role.instance.name
  policy = data.aws_iam_policy_document.cloudwatch_agent[0].json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-instance"
  role = aws_iam_role.instance.name
}

moved {
  from = aws_instance.k3s
  to   = aws_instance.k3s[0]
}

resource "aws_instance" "k3s" {
  count                       = 2
  ami                         = local.selected_ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  user_data                   = var.bootstrap_script
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size

    tags = {
      Name = "${var.name_prefix}-root"
    }
  }

  tags = {
    Name       = "${var.name_prefix}-k3s-${count.index == 0 ? "server" : "agent"}"
    Ansible    = count.index == 0 ? "k3s-server" : "k3s-agent"
    Kubernetes = "k3s"
    K3sRole    = count.index == 0 ? "server" : "agent"
  }

  lifecycle {
    precondition {
      condition     = data.aws_ec2_instance_type.selected.free_tier_eligible
      error_message = "Le type EC2 sélectionné doit être éligible au Free Tier dans la région AWS courante."
    }

    precondition {
      condition     = contains(data.aws_ec2_instance_type.selected.supported_architectures, "x86_64")
      error_message = "Le type EC2 sélectionné doit prendre en charge x86_64 pour l'AMI Debian amd64 du POC."
    }

    precondition {
      condition     = data.aws_ec2_instance_type.selected.default_vcpus >= 2 && data.aws_ec2_instance_type.selected.memory_size >= 4096
      error_message = "Le nœud K3s nécessite au minimum 2 vCPU et 4 Gio de RAM."
    }
  }

  depends_on = [aws_iam_role_policy_attachment.ssm]
}
