# ==========================================
# INPUT VARIABLES CONFIGURATION
# ==========================================

variable "aws_region" {
  type        = string
  description = "The AWS Target Deployment Region"
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  type        = string
  description = "Base CIDR range for the automated VPC"
  default     = "10.90.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR range for the front-facing public web tier"
  default     = "10.90.1.0/24"
}
# 🛡️  ALB have must two public subnets 
variable "public_subnet_b_cidr" {
  type        = string
  description = "CIDR block for the second redundant public subnet tier"
  default     = "10.90.3.0/24" # A fresh, unconflicting network lane
}


variable "private_subnet_cidr" {
  type        = string
  description = "CIDR range for the isolated backend database tier"
  default     = "10.90.2.0/24"
}

variable "public_instance_ami" {
  type        = string
  description = "AMI ID for the public Nginx web server"
  default     = "ami-04df7d76c1b804451" # Ubuntu 22.04 LTS
}

variable "private_instance_ami" {
  type        = string
  description = "AMI ID for the isolated backend server"
  default     = "ami-04df7d76c1b804451" # Ubuntu 22.04 LTS
}

variable "instance_type" {
  type        = string
  description = "EC2 computing tier footprint size"
  default     = "t3.micro"
}


# 🐳 Docker
# NEW DEPLOYMENT CONFIGURATIONS
variable "container_image" {
  type        = string
  description = "Docker Hub image used by the ECS Fargate task"
  default     = "minddecoders/storefront-app:v1.0"
}

variable "container_port" {
  type        = number
  description = "Port exposed by the container"
  default     = 80
}


