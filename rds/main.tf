# 1. Private Database Subnet Group (Spread across multiple AZs)
resource "aws_db_subnet_group" "this" {
  name       = "nexora-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "nexora-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# 2. Database Firewall (Updates rules in-place without recreation)
resource "aws_security_group" "db_sg" {
  name        = "nexora-${var.environment}-db-sg"
  description = "Allow inbound MySQL traffic exclusively from EKS" # <-- Keep original text!
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from private subnets"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
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
# 3. Cryptographically Random Passwords & Platform Keys
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "internal_service_secret" {
  length  = 32
  special = false
}

# 4. Store ALL Credentials in AWS Secrets Manager (Zero Secrets in Git!)
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "nexora/${var.environment}/db-credentials"
  recovery_window_in_days = 0

  tags = {
    Environment = var.environment
    Project     = "NexoraPlatform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    DB_HOST                 = aws_db_instance.this.address
    DB_PORT                 = "3306"
    DB_USER                 = "dbadmin"
    DB_PASSWORD             = random_password.db_password.result
    DB_NAME                 = var.database_name
    JWT_SECRET              = random_password.jwt_secret.result
    INTERNAL_SERVICE_SECRET = random_password.internal_service_secret.result
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
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:30-Sun:05:30"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "nexora-${var.environment}-mysql"
    Environment = var.environment
  }
}
