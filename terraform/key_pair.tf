# Usa uma chave publica SSH ja existente na maquina local.
# Gere uma antes, se necessario, com: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
resource "aws_key_pair" "lab" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = { Name = "${var.project_name}-${var.environment}-key" }
}
