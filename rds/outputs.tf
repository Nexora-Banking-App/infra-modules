output "db_endpoint" {
  description = "The connection endpoint for the MySQL instance"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.this.address
}

output "secrets_manager_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret holding the database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_security_group_id" {
  description = "The security group ID of the database"
  value       = aws_security_group.db_sg.id
}