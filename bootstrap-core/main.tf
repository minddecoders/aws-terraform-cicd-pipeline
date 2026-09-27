terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# ============================================================================
# 🛰️ 1. GLOBAL OIDC IDENTITY PROVIDER HOOK
# ============================================================================
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd", "a031c46782e6e6c662c2c87c76da9aa62ccabd8e", "57535917a0d120df61559d93daf1e9b011403b22"]
}

# ============================================================================
# 🛡️ 2. PERMANENT KEYLESS EXECUTION ROLE ASSUMED BY GITHUB ACTIONS
# ============================================================================
resource "aws_iam_role" "github_oidc_role" {
  name        = "sidra-github-actions-oidc-execution-role"
  description = "Permanent role assumed by automated GitHub Actions runners using temporary keyless session tokens"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"

        # 🚀 UNIFIED SECURITY EVALUATION: Standard text fields matching GitHub format token guidelines!
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:minddecoders/aws-terraform-cicd-pipeline:*"
          }
        }
      }
    ]
  })
}

# ============================================================================
# 🛡️ 3. ATTACH ADMINISTRATOR PERMISSION POLICY WIRE
# ============================================================================
resource "aws_iam_role_policy_attachment" "oidc_admin_attach" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============================================================================
# 📡 PHASE 8 TELEMETRY OUTPUT
# ============================================================================
output "github_actions_oidc_role_arn" {
  value       = aws_iam_role.github_oidc_role.arn
  description = "The target IAM role ARN used by GitHub Actions for temporary AWS credentials"
}
