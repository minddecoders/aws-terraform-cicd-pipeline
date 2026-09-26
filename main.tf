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
  # 💾 FIXED BACKEND: Cleanly separated lines to guarantee S3 state tracking syncs!
  backend "s3" {
    bucket       = "sidra-prod-state-vault-2026"
    key          = "cicd-pipeline/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
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

resource "aws_subnet" "sidra_public_subnet" {
  vpc_id            = aws_vpc.sidra_automated_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "sidra-automated-public-1a" }
}

resource "aws_route_table_association" "sidra_public_assoc" {
  subnet_id      = aws_subnet.sidra_public_subnet.id
  route_table_id = aws_route_table.sidra_public_rt.id
}
# 🛡️ ALB have must two public subnets 
resource "aws_subnet" "sidra_public_subnet_b" {
  vpc_id            = aws_vpc.sidra_automated_vpc.id
  cidr_block        = var.public_subnet_b_cidr
  availability_zone = "eu-west-1b" # 🛰️ Separate availability zone building!

  tags = {
    Name = "sidra-automated-public-1b"
  }
}
# 🛡️ ALB
resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.sidra_public_subnet_b.id
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
  name = "EC2-SSM-Core-Role-TF-prod-cicd-2026" # 🔄 UNIQUE ROLE NAME!

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
  name = "EC2-SSM-Instance-Profile-TF-prod-cicd-2026"
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
# ==========================================================
# 🐳 ECS
# PHASE 6: SERVERLESS CONTAINER ORCHESTRATION (ECS & FARGATE)
# ==========================================================

# ⭐ CloudWatch
# ADDITION 1: Dedicated Cloud Storage Vault Room for System Connection Logs
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/sidra-storefront-production-logs"
  retention_in_days = 7 # FinOps optimization rule to clear old logs automatically

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
  }
}

resource "aws_ecs_cluster" "sidra_cluster" {
  name = "sidra-healthcare-production-cluster"

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "sidra-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "sidra_task" {
  family                   = "sidra-storefront-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "sidra-storefront"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      # # ⭐ CloudWatch : ADDITION 3: Telemetry system configuration driver argument array!
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
  }
}


resource "aws_ecs_service" "sidra_service" {
  name            = "sidra-storefront-service"
  cluster         = aws_ecs_cluster.sidra_cluster.id
  task_definition = aws_ecs_task_definition.sidra_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.sidra_public_subnet.id]
    security_groups  = [aws_security_group.sidra_web_sg.id]
    assign_public_ip = true
  }


  # 🛡️ ALB
  # ENTERPRISE BINDING: Hooks your Fargate task right behind your Load Balancer router!
  load_balancer {
    target_group_arn = aws_lb_target_group.sidra_ecs_tg.arn
    container_name   = "sidra-storefront"
    container_port   = var.container_port
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_lb_listener.sidra_http_listener # Guarantees the listener exists before the container hooks in
  ]
}

# ==========================================================
#  🛡️ ALB 
# PHASE 7: ENTERPRISE HIGH-AVAILABILITY APPLICATION LOAD BALANCER
# ==========================================================

# 1. Public External Application Load Balancer Router
resource "aws_lb" "sidra_alb" {
  name               = "sidra-healthcare-prod-alb"
  internal           = false # Setting to false creates an internet-facing public router
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sidra_web_sg.id]
  # 💥 FIXED DUAL PUBLIC INGRESS HOOKS: Connected to two real public zones!
  subnets = [aws_subnet.sidra_public_subnet.id, aws_subnet.sidra_public_subnet_b.id]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
  }
}

# 2. ALB Target Group Routing Vault Bucket Container
resource "aws_lb_target_group" "sidra_ecs_tg" {
  name        = "sidra-ecs-storefront-tg"
  port        = var.container_port # Directs traffic onto container port 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.sidra_automated_vpc.id
  target_type = "ip" # This flag is mandatory when routing traffic onto serverless AWS Fargate tasks

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform-IaC"
  }
}

# 3. ALB Listener Gatekeeper Entry Process
resource "aws_lb_listener" "sidra_http_listener" {
  load_balancer_arn = aws_lb.sidra_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sidra_ecs_tg.arn
  }
}
