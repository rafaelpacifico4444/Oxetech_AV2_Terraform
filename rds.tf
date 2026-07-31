resource "aws_db_subnet_group" "lab" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-${var.environment}-db-subnet-group" }
}

resource "aws_db_instance" "lab" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version

  # Free tier
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.lab.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = false
  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = { Name = "${var.project_name}-${var.environment}-db" }
}
