resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "k3s" {
  name        = "${var.name_prefix}-k3s"
  description = "Public HTTP(S) only; administration uses AWS Systems Manager"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-k3s"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.http_ingress_cidrs)

  security_group_id = aws_security_group.k3s.id
  description       = "HTTP to Traefik"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.http_ingress_cidrs)

  security_group_id = aws_security_group.k3s.id
  description       = "HTTPS to Traefik"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# POC : sans NAT Gateway ni VPC endpoints, HTTP est requis pour les dépôts
# Ubuntu. Cette exception temporaire doit être remplacée avant la production.
#trivy:ignore:AWS-0104:exp:2026-12-31
resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.k3s.id
  description       = "HTTP for Ubuntu package repositories"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# POC : sans NAT Gateway ni VPC endpoints, HTTPS est requis pour AWS SSM,
# les registries et le GitLab Agent. Cette exception expire avant la production.
#trivy:ignore:AWS-0104:exp:2026-12-31
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.k3s.id
  description       = "HTTPS for SSM, registries and GitLab Agent"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "amazon_time_sync" {
  security_group_id = aws_security_group.k3s.id
  description       = "NTP to Amazon Time Sync Service"
  cidr_ipv4         = "169.254.169.123/32"
  from_port         = 123
  to_port           = 123
  ip_protocol       = "udp"
}
