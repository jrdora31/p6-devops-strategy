# Le module fournit un réseau public minimal : une seule subnet, une route
# Internet et deux Security Groups séparant le NLB des nœuds K3s.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# L'Internet Gateway donne une cible à la route par défaut de la subnet publique.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Les EC2 reçoivent une IP publique car ce POC ne déploie ni NAT Gateway ni endpoints.
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

# La route 0.0.0.0/0 rend la subnet publique via l'Internet Gateway.
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

# Les Security Groups sont déclarés sans règles inline pour gérer chaque flux
# comme une ressource Terraform indépendante.
resource "aws_security_group" "k3s" {
  name        = "${var.name_prefix}-k3s"
  description = "K3s nodes; administration uses AWS Systems Manager"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-k3s"
  }
}

resource "aws_security_group" "nlb" {
  name        = "${var.name_prefix}-nlb"
  description = "Public HTTP entry point for the MicroCRM NLB"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-nlb"
  }
}

# Autorise uniquement les échanges internes entre les nœuds portant ce SG.
resource "aws_vpc_security_group_ingress_rule" "k3s_nodes" {
  security_group_id            = aws_security_group.k3s.id
  description                  = "Internal traffic between K3s nodes"
  referenced_security_group_id = aws_security_group.k3s.id
  ip_protocol                  = "-1"
}

# La règle sortante complète l'échange bidirectionnel entre membres du même SG.
resource "aws_vpc_security_group_egress_rule" "k3s_nodes" {
  security_group_id            = aws_security_group.k3s.id
  description                  = "Internal traffic between K3s nodes"
  referenced_security_group_id = aws_security_group.k3s.id
  ip_protocol                  = "-1"
}

# L'entrée publique s'arrête au NLB; seuls les CIDR explicitement fournis
# peuvent atteindre son listener HTTP.
resource "aws_vpc_security_group_ingress_rule" "http" {
  # Une ressource distincte est créée pour chaque CIDR afin de garder un diff lisible.
  for_each = toset(var.http_ingress_cidrs)

  security_group_id = aws_security_group.nlb.id
  description       = "Public HTTP to the NLB"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Les deux règles référencées par Security Group forment le chemin symétrique
# NLB -> Traefik sur le port 80, y compris pour les contrôles de santé.
resource "aws_vpc_security_group_egress_rule" "nlb_to_k3s_http" {
  security_group_id            = aws_security_group.nlb.id
  description                  = "HTTP from the NLB to Traefik on K3s nodes"
  referenced_security_group_id = aws_security_group.k3s.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nlb_to_k3s_http" {
  # La référence au SG du NLB est plus restrictive qu'un CIDR du VPC entier.
  security_group_id            = aws_security_group.k3s.id
  description                  = "HTTP and health checks from the NLB"
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# POC : sans NAT Gateway ni VPC endpoints, HTTP est requis pour les dépôts de
# paquets. Cette exception temporaire doit être remplacée avant la production.
#trivy:ignore:AWS-0104:exp:2026-12-31
resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.k3s.id
  description       = "HTTP for package repositories"
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

# L'horloge des nœuds reste synchronisée avec le service link-local AWS sans
# ouvrir le trafic NTP vers Internet.
resource "aws_vpc_security_group_egress_rule" "amazon_time_sync" {
  security_group_id = aws_security_group.k3s.id
  description       = "NTP to Amazon Time Sync Service"
  cidr_ipv4         = "169.254.169.123/32"
  from_port         = 123
  to_port           = 123
  ip_protocol       = "udp"
}
