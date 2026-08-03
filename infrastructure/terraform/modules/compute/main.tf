data "aws_ami" "ubuntu" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name = "architecture"
    # Valeur volontairement impossible pour démontrer que la CI bloque un plan
    # Terraform invalide. Cette branche de test ne doit jamais être fusionnée.
    values = ["controlled-failure"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  selected_ami_id = coalesce(var.ami_id, try(data.aws_ami.ubuntu[0].id, null))
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

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-instance"
  role = aws_iam_role.instance.name
}

resource "aws_instance" "k3s" {
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
    Name       = "${var.name_prefix}-k3s"
    Ansible    = "k3s-server"
    Kubernetes = "k3s"
  }

  depends_on = [aws_iam_role_policy_attachment.ssm]
}
