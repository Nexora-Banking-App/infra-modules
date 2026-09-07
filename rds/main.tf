# 1. Private Database Subnet Group (Spread across multiple AZs)
resource "aws_db_subnet_group" "this" {
  name       = "nexora-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "nexora-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# 2. Database Firewall (Only permits incoming traffic from EKS)
resource "aws_security_group" "db_sg" {
  name        = "nexora-${var.environment}-db-sg"
  description = "Allow inbound MySQL traffic exclusively from EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "nexora-${var.environment}-db-sg"
    Environment = var.environment
  }
}

# 3. Cryptographically Random Master Password
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 4. Store Credentials in AWS Secrets Manager for GitOps (ESO) Consumption
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "nexora/${var.environment}/db-credentials"
  recovery_window_in_days = 0 # Forces immediate deletion if destroyed during demos

  tags = {
    Environment = var.environment
    Project     = "NexoraPlatform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    DB_HOST     = aws_db_instance.this.address
    DB_PORT     = "3306"
    DB_USER     = "dbadmin"
    DB_PASSWORD = random_password.db_password.result
    DB_NAME     = var.database_name
  })
}

# 5. The RDS MySQL Engine Instance
resource "aws_db_instance" "this" {
  identifier = "nexora-${var.environment}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = "dbadmin"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # HA Configuration: Synchronous standby in Prod, standalone in Staging
  multi_az = var.multi_az

  # Backup & PITR Retention (Crucial for our DR demonstration)
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:30-Sun:05:30"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "nexora-${var.environment}-mysql"
    Environment = var.environment
  }
}