# iam-github-oidc.tf
#
# Configuração OIDC (OpenID Connect) para GitHub Actions
# Permite que workflows do GitHub assumam uma IAM Role na AWS
# sem precisar armazenar AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#
# Segurança:
# - Credenciais são geradas TEMPORARIAMENTE (1 hora por padrão)
# - Cada workflow tem seu próprio session name
# - Tudo é auditável no CloudTrail
# - Não precisa rotacionar chaves
#

# 1. Buscar certificado de identidade do GitHub
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# 2. Criar o OIDC Provider na AWS
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  url             = "https://token.actions.githubusercontent.com"

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}

# 3. Criar IAM Role que GitHub Actions vai assumir
resource "aws_iam_role" "github_actions" {
  name                 = "${var.project_name}-${var.environment}-github-actions-role"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600 # 1 hora

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# 4. Policy: Permitir que GitHub assuma a role via OIDC
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restricão IMPORTANTE: só permite workflows do seu repositório
    # Altere "rafaelpacifico4444/Oxetech_AV2_Repo" para seu repo completo
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:rafaelpacifico4444/Oxetech_AV2_Terraform:ref:refs/heads/master",
        "repo:rafaelpacifico4444/Oxetech_AV2_Terraform:environment:production",
        "repo:rafaelpacifico4444/Oxetech_AV2_Terraform:pull_request"
      ]
    }
  }
}

# 5. Policy: Permitir que role faça Terraform apply/destroy
resource "aws_iam_role_policy" "github_actions_terraform" {
  name   = "github-actions-terraform-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_terraform.json
}

data "aws_iam_policy_document" "github_actions_terraform" {
  # EC2 (instâncias, security groups, etc)
  statement {
    effect = "Allow"
    actions = [
      "ec2:*"
    ]
    resources = ["*"]
  }

  # RDS (banco de dados)
  statement {
    effect = "Allow"
    actions = [
      "rds:*"
    ]
    resources = ["*"]
  }

  # S3 (buckets)
  statement {
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = ["*"]
  }

  # IAM (roles, policies)
  statement {
    effect = "Allow"
    actions = [
      "iam:*"
    ]
    resources = ["*"]
  }

  # Lambda (funções)
  statement {
    effect = "Allow"
    actions = [
      "lambda:*"
    ]
    resources = ["*"]
  }

  # API Gateway (endpoints)
  statement {
    effect = "Allow"
    actions = [
      "apigateway:*"
    ]
    resources = ["*"]
  }

  # CloudFront (CDN)
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:*"
    ]
    resources = ["*"]
  }

  # Route 53 (DNS)
  statement {
    effect = "Allow"
    actions = [
      "route53:*"
    ]
    resources = ["*"]
  }

  # ACM (certificados SSL)
  statement {
    effect = "Allow"
    actions = [
      "acm:*"
    ]
    resources = ["*"]
  }

  # ALB (load balancer)
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*"
    ]
    resources = ["*"]
  }

  # ASG (auto scaling)
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:*"
    ]
    resources = ["*"]
  }

  # SSM (Session Manager + SendCommand)
  statement {
    effect = "Allow"
    actions = [
      "ssm:*"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    effect = "Allow"
    actions = [
      "logs:*"
    ]
    resources = ["*"]
  }

  # CloudWatch (métricas)
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:*"
    ]
    resources = ["*"]
  }

  # VPC (redes)
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute"
    ]
    resources = ["*"]
  }

  # KMS (criptografia)
  statement {
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
  }

  # SNS (notificações)
  statement {
    effect = "Allow"
    actions = [
      "sns:*"
    ]
    resources = ["*"]
  }

  # Permissões gerais de leitura (state, descrições, etc)
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "rds:Describe*",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

# 6. Outputs para usar no GitHub
output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN do OIDC Provider (para referência)"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN da role que GitHub Actions vai assumir - COPIE ISTO PARA O GITHUB SECRET: AWS_ROLE_ARN"
}

output "github_actions_role_name" {
  value       = aws_iam_role.github_actions.name
  description = "Nome da role (para debug)"
}
