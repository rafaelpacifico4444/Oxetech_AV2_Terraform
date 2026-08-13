# lab-iac — Infraestrutura como Código (Terraform + AWS + GitHub Actions)

Projeto de infraestrutura cloud para a aplicação Flask **OlhaNuvem**, provisionada inteiramente via Terraform na AWS. Inclui banco de dados RDS PostgreSQL, CDN com CloudFront e dois fluxos de automação: um pipeline de **CI/CD via GitHub Actions** para a infraestrutura, e um deploy de aplicação serverless automático com **Webhook + Lambda + SSM**.

---
## Estrutura do Projeto

```
Oxetech_AV2_Terraform/
├── .github/
│   └── workflows/
│       ├── terraform-validate.yml      # CI: Validação e TFLint em PRs
│       ├── terraform-apply.yml         # CD: Deploy da infra na master
│       └── deploy-lambda-webhook.yml   # CD: Deploy Python Lambda
|
│──.env                                 # Variáveis locais 
|──.gitignore
|
│── scripts/
│     └── user-data.sh                  # Inicialização das instâncias
|
├── lambda/
│   └── webhook/
│       └── lambda_function.py          # Handler Python do webhook GitHub
|
└── terraform/
    ├── main.tf                         # Providers e backend S3
    ├── variables.tf                    # Declaração de variáveis
    ├── terraform.tfvars                # Valores não-sensíveis (comitado)
    ├── outputs.tf                      # Outputs pós-apply
    ├── vpc.tf, rds.tf, alb.tf, asg.tf  # Definições de recursos 
    ├── cloudfront.tf, acm_route53.tf   # CDN, SSL e DNS
    ├── lambda.tf, api_gateway.tf       # API e Função Serverless
    └── iam.tf                          # Roles e permissões
```

---
## Arquitetura e Fluxos

```
                     [ Fluxo do Usuário Final ]
Usuário
  │
  ▼
CloudFront (CDN + HTTPS forçado)
  │
  ▼
Internet Gateway
  │
  ▼
ALB (Application Load Balancer)
  │
  ├── Listener HTTP :80  → forward interno
  └── Listener HTTPS :443 → forward
          │
          ▼
    Auto Scaling Group (Ubuntu 24.04 + Nginx + Gunicorn + Flask)
          │
          ▼
        RDS PostgreSQL (subnet privada)
        
------------------------------------------------------------------------
        
                        [ Fluxo do Push ]
                     
     Git push → API Gateway → Lambda → SSM → EC2 (git pull + restart)
```


![Arquitetura da rede](Pasted image 20260813194054.png)

---
### Fluxos de Automação e Deploy

O projeto possui fluxos separados para Código da Infraestrutura e Código da Aplicação:

1. **Deploy de Infraestrutura & Lambda (GitHub Actions):**
    
    - Push/PR no Terraform engatilha o workflow de validação e Apply automático usando chaves estáticas (`AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`).
        
    - Push no diretório `lambda/` engatilha a atualização exclusiva do `.zip` da função.
        
2. **Deploy da Aplicação Flask (Webhook):**
    
    - Push na branch `master` do repositório da aplicação envia um payload ao API Gateway.
        
    - A Lambda valida o HMAC-SHA256, invoca o AWS SSM e roda `git pull && systemctl restart gunicorn` nas instâncias web.

---
## Pré-requisitos

- Terraform >= 1.15.8 instalado.
    
- AWS CLI configurado (`aws configure`).
    
- Plugin do Session Manager instalado localmente.
    
- Domínio registrado (name.com ou outro).
    
- Repositório GitHub com a aba **Secrets** configurada.

---
## Variáveis e Secrets


### `terraform.tfvars` (não-sensíveis)

| Variável          | Descrição                           | Valor padrão        |     |     |
| ----------------- | ----------------------------------- | ------------------- | --- | --- |
| `owner`           | Responsável pelo ambiente           | —                   |     |     |
| `aws_region`      | Região AWS                          | `sa-east-1`         |     |     |
| `project_name`    | Nome do projeto                     | `lab-iac`           |     |     |
| `environment`     | Ambiente (`dev`, `test`, `staging`) | `dev`               |     |     |
| `instance_type`   | Tipo de instância EC2               | `t3.micro`          |     |     |
| `release_version` | Tag de versão do release            | `v1`                |     |     |
| `domain_name`     | Domínio raiz                        | `olhanuvem.dev`     |     |     |
| `subdomain`       | Subdomínio do site                  | `www`               |     |     |
| `bucket_name`     | Nome do bucket S3                   | —                   |     |     |
| `db_name`         | Nome do banco de dados              | `labdb`             |     |     |
| `db_username`     | Usuário do banco                    | `dbadmin`           |     |     |
| `public_key_path` | Caminho da chave pública SSH        | `~/.ssh/id_rsa.pub` |     |     |

### `GitHub Secrets` (Sensíveis)

Nunca devem ser commitadas. Cadastre os seguintes **Repository Secrets** no GitHub para os Actions funcionarem:

- `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`: Autenticação GitHub Actions
    
- `TF_VAR_DB_PASSWORD`: Senha do RDS
    
- `TF_VAR_FLASK_SECRET_KEY`: Chave do Flask (usada para sessões)
    
- `TF_VAR_GITHUB_WEBHOOK_SECRET`: Segredo de validação da Lambda
    
- `SLACK_WEBHOOK_URL`: Opcional, para notificações de sucesso/falha do Actions.
    
- `TF_VAR_DOMAIN_NAME`: Utilizado para configurar o domínio principal

---
# Como Provisionar

Com a adição do GitHub Actions, o pipeline assume a maior parte do trabalho, mas a configuração inicial de DNS exige um passo local:

### 1. Criar a Hosted Zone (Setup Local)

Carregue suas variáveis localmente via `.env` e aplique apenas a zona DNS:

Bash
```
source .env
terraform init
terraform apply -target=aws_route53_zone.primary
```

Pegue os nameservers e atualize no seu provedor de domínio (Aguarde a propagação).

### 2. Validar os Certificados (Setup Local)

Bash
```
terraform apply -target=aws_acm_certificate.site -target=aws_acm_certificate.cdn
```

### 3. Apply Automático via GitHub

Faça um _push_ do seu código para a `main`. O GitHub Actions rodará o plano e aplicará o restante da infraestrutura automaticamente, publicando os outputs no final da execução.

### 4. Configurar Webhook no Repositório da Aplicação

Pegue o output do Actions (`webhook_url`) e cadastre no GitHub da aplicação Flask apontando para `application/json` e utilizando o evento `Just the push event`.

---

# Verificar se o site está no ar

```bash
# Status geral
curl -I -L https://www.olhanuvem.dev

# Health check do ALB
curl -I https://www.olhanuvem.dev/health

# Verificar certificado SSL/TLS
curl -vI https://www.olhanuvem.dev 2>&1 | grep -E "subject|issuer|SSL"

# Confirmar CloudFront na frente
curl -I https://www.olhanuvem.dev 2>&1 | grep -i "x-cache"
```

---
## Como destruir

### 1. Desativar o webhook no GitHub

Acesse Settings → Webhooks e remova o webhook antes de destruir para evitar erros de chamadas para URL inexistente.

### 2. Plan de destroy

```bash
source .env
terraform plan -destroy
```

### 3. Destroy

```bash
terraform destroy
```

> O RDS tem `skip_final_snapshot = true` e `deletion_protection = false`, portanto será destruído sem snapshots. Se quiser preservar os dados, ajuste essas configurações antes do destroy.


---
## Outputs do Terraform

Exportados ao final do pipeline:

- `website_url`: URL final (`[https://www.olhanuvem.dev](https://www.olhanuvem.dev)`)
    
- `webhook_url`: Endpoint do API Gateway para a Lambda
    
- `alb_dns_name` e `cloudfront_domain_name`
    
- `rds_endpoint` (Sensível)

---
## Segurança

- **Credenciais Automáticas:** Uso do GitHub Actions com Secrets blindados em injeção nas variáveis de ambiente (`env:` e `with:`).
    
- **Acesso EC2 Restrito:** Sem porta 22 exposta; acesso apenas via SSM Session Manager.
    
- **Isolamento de Banco:** RDS alocado estritamente em subnet privada, recebendo tráfego apenas do SG do ASG.
    
- **Autenticação de Webhook:** Criptografia via HMAC-SHA256 validada dentro do código Python da Lambda.
    
- **Metadados:** Exigência de IMDSv2 nas instâncias (`http_tokens = "required"`).
    
- **Armazenamento:** Volumes EBS e bucket S3 com criptografia ativada.
