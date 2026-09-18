# ==========================================
# PHASE 1: TARGET CLOUD PROVIDER PLUGINS
# ==========================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
# PHASE 2: STRUCTURAL NETWORK ARCHITECTURE
# ==========================================
resource "aws_vpc" "sidra_automated_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "sidra-automated-vpc" }
}

resource "aws_subnet" "sidra_public_subnet" {
  vpc_id            = aws_vpc.sidra_automated_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "sidra-automated-public-1a" }
}

resource "aws_internet_gateway" "sidra_igw" {
  vpc_id = aws_vpc.sidra_automated_vpc.id
}

resource "aws_route_table" "sidra_public_rt" {
  vpc_id = aws_vpc.sidra_automated_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sidra_igw.id
  }
}

resource "aws_route_table_association" "sidra_public_assoc" {
  subnet_id      = aws_subnet.sidra_public_subnet.id
  route_table_id = aws_route_table.sidra_public_rt.id
}

resource "aws_security_group" "sidra_web_sg" {
  name        = "sidra-automated-web-sg"
  vpc_id      = aws_vpc.sidra_automated_vpc.id
  description = "Isolate instances while leaving Port 22 closed to the public internet"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# PHASE 3: SECURE IAM IDENTITY MANAGEMENT
# ==========================================
resource "aws_iam_role" "ssm_role" {
  name = "EC2-SSM-Core-Role-TF-prod" # 🔄 UNIQUE ROLE NAME!

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  # 🔄 FIXED UNIQUE NAME: Append "-prod" to bypass global profile conflicts!
  name = "EC2-SSM-Instance-Profile-TF-prod"
  role = aws_iam_role.ssm_role.name
}


# ==========================================
# PHASE 4: COMPLIANT KEYLESS COMPUTE ENGINE
# ==========================================
resource "aws_instance" "ssm_vm" {
  ami                         = var.public_instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.sidra_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.sidra_web_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install nginx -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF

  tags = {
    Name      = "sidra-ssm-terraform-demo"
    ManagedBy = "Terraform-IaC"
  }
}

# ==========================================================
# PHASE 5: ISOLATED PRIVATE NETWORK & SECURITY ISOLATION PROD TIER
# ==========================================================
resource "aws_subnet" "sidra_private_subnet" {
  vpc_id            = aws_vpc.sidra_automated_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "sidra-automated-private-1b" }
}

resource "aws_route_table" "sidra_private_rt" {
  vpc_id = aws_vpc.sidra_automated_vpc.id

  tags = {
    Name        = "sidra-automated-private-rt"
    Environment = "Production"
  }
}

resource "aws_route_table_association" "sidra_private_assoc" {
  subnet_id      = aws_subnet.sidra_private_subnet.id
  route_table_id = aws_route_table.sidra_private_rt.id
}

resource "aws_security_group" "sidra_private_db_sg" {
  name        = "sidra-automated-private-db-sg"
  description = "Block all public access and whitelist internal database traffic queries only"
  vpc_id      = aws_vpc.sidra_automated_vpc.id

  ingress {
    description     = "Allow internal database queries exclusively from the front-end web tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sidra_web_sg.id]
  }

  ingress {
    description     = "Allow internal management traffic from the public web host"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.sidra_web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sidra-automated-private-db-sg"
    Environment = "Production"
  }
}

resource "aws_instance" "ssm_private_vm" {
  ami                         = var.private_instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.sidra_private_subnet.id
  vpc_security_group_ids      = [aws_security_group.sidra_private_db_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name      = "sidra-ssm-private-backend"
    ManagedBy = "Terraform-IaC"
  }
}


