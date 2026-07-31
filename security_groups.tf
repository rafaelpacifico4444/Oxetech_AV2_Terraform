# ---------------------------------------------------------------------------
# SG do Load Balancer: recebe HTTP/HTTPS da internet
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Permite HTTP/HTTPS publico para o ALB"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-alb-sg" }

  lifecycle { create_before_destroy = true }
}

# ---------------------------------------------------------------------------
# SG das instâncias EC2 (ASG): só aceita trafego vindo do ALB
# ---------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-${var.environment}-web-"
  description = "Permite HTTP somente a partir do ALB"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description     = "HTTP a partir do ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Saida para instalacao de pacotes e acesso ao RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-web-sg" }

  lifecycle { create_before_destroy = true }
}

# ---------------------------------------------------------------------------
# SG do RDS: só aceita trafego vindo das instancias web
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Permite acesso ao banco somente a partir das instancias web"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description     = "Banco de dados a partir das instancias web"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-rds-sg" }

  lifecycle { create_before_destroy = true }
}
