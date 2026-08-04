# lambda.tf

# ── Empacota o .py em .zip automaticamente ──────────────────────────────────
data "archive_file" "webhook" {
  type        = "zip"
  source_file = "${path.module}/../lambda/webhook/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# ── IAM Role da Lambda ───────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_webhook" {
  name = "${var.project_name}-${var.environment}-lambda-webhook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Logs no CloudWatch (já incluso na policy gerenciada)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_webhook.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permissão para chamar SSM SendCommand nas instâncias do ASG
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "ssm-send-command"
  role = aws_iam_role.lambda_webhook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:SendCommand"
        Resource = [
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
          "arn:aws:ec2:${var.aws_region}:*:instance/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "*"
      }
    ]
  })
}

# ── Função Lambda ─────────────────────────────────────────────────────────────
resource "aws_lambda_function" "webhook" {
  function_name    = "${var.project_name}-${var.environment}-webhook"
  role             = aws_iam_role.lambda_webhook.arn
  filename         = data.archive_file.webhook.output_path
  source_code_hash = data.archive_file.webhook.output_base64sha256
  runtime          = "python3.12"
  handler          = "lambda_function.handler"
  timeout          = 30

  environment {
    variables = {
      GITHUB_WEBHOOK_SECRET = var.github_webhook_secret
    }
  }

  tags = { Name = "${var.project_name}-${var.environment}-webhook" }
}