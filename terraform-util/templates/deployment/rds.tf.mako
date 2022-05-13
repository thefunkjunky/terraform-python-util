resource "aws_db_subnet_group" "default_db" {
  name       = <%text>"${var.environment}-default_db"</%text>
  % if db_publicly_accesible == "true":
  subnet_ids = module.vpc_networking.public_subnet_ids
  % else:
  subnet_ids = module.vpc_networking.private_subnet_ids
  % endif
}

resource "aws_db_instance" "default_db" {
  identifier           = var.db_identifier
  allocated_storage    = var.db_storage_size
  max_allocated_storage = var.db_max_allocated_storage
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  name                 = var.db_name
  username             = "dbadmin"
  % if db_password_encrypted:
  password             = data.aws_kms_secrets.secrets.plaintext["db_password"]
  % else:
  password             = "${db_temp_password}"
  % endif
  parameter_group_name = "default.postgres11"
  publicly_accessible  = var.db_publicly_accesible
  skip_final_snapshot  = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  db_subnet_group_name = aws_db_subnet_group.default_db.name  
  # TODO: Look into this and figure out that IAM bit
  # monitoring_interval = 60
  # monitoring_role_arn = "arn:aws:iam::835798820667:role/BetteromicsEMforRDS"
  # performance_insights_enabled = true
}
