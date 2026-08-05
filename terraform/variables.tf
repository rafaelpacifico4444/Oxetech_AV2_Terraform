variable "aws_region" {
  description = "Região AWS do laboratório"
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "lab-iac"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "staging"], var.environment)
    error_message = "Use dev, test ou staging."
  }
}

variable "owner" {
  description = "Responsável pelo ambiente"
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "Owner não pode ser vazio."
  }
}

# ---------------------------------------------------------------------------
# Rede
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs das duas subnets públicas"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das duas subnets privadas"
  type        = list(string)
  default     = ["10.10.11.0/24", "10.10.12.0/24"]
}

# ---------------------------------------------------------------------------
# Computação (Launch Template + ASG)
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "Tipo de instância EC2 (free tier)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Use apenas t2.micro ou t3.micro."
  }
}

variable "release_version" {
  description = "Versão de release usada como tag (para praticar mudança controlada)"
  type        = string
  default     = "v1"
}

variable "asg_min_size" {
  description = "Tamanho mínimo do Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Tamanho máximo do Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Capacidade desejada do Auto Scaling Group"
  type        = number
  default     = 2
}

# ---------------------------------------------------------------------------
# Key pair
# ---------------------------------------------------------------------------

variable "public_key_path" {
  description = "Caminho local da chave pública SSH (ex: ~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "key_name" {
  description = "Nome do key pair na AWS"
  type        = string
  default     = "key-pair-av2-1"
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

variable "db_engine" {
  description = "Engine do banco de dados"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Versão do engine do banco"
  type        = string
  default     = "16.13"
}

variable "db_instance_class" {
  description = "Classe da instância RDS (free tier)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Usuário administrador do banco"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha do administrador do banco (defina via TF_VAR_db_password ou terraform.tfvars, nunca commitada)"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado do RDS em GB (free tier: até 20GB)"
  type        = number
  default     = 20
}

# ---------------------------------------------------------------------------
# Aplicação Flask
# ---------------------------------------------------------------------------

variable "flask_secret_key" {
  description = "Chave usada pelo Flask para assinar cookies de sessão e tokens CSRF. Precisa ser igual em todas as instâncias do ASG (defina via TF_VAR_flask_secret_key, nunca commitada). Gere com: openssl rand -hex 32"
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# S3
# ---------------------------------------------------------------------------

variable "bucket_name" {
  description = "Nome do bucket S3 (precisa ser globalmente único)"
  type        = string
}

# ---------------------------------------------------------------------------
# Route 53 + ACM
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Domínio raiz já registrado e com hosted zone existente no Route 53 (ex: meusite.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "ID da hosted zone pública existente no Route 53 para o domínio raiz"
  type        = string
  default     = "Z038815616BMKEPRA3A7R"
}

variable "subdomain" {
  description = "Subdomínio usado para o site (ex: www -> www.meusite.com). Deixe vazio para usar o domínio raiz."
  type        = string
  default     = "www"
}


# WebHook

variable "github_webhook_secret" {
  description = "Segredo compartilhado entre GitHub e a Lambda para validar webhooks. Gere com: openssl rand -hex 32"
  type        = string
  sensitive   = true
}