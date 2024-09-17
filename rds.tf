# RDS
resource "aws_db_subnet_group" "mission_db_group" {
  name       = "${var.namespace}-db-group"
  subnet_ids = values(aws_subnet.private)[*].id

  tags = {
    Name = "${var.namespace}-db-group"
  }
}

resource "random_password" "default" {
  length           = 25
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name_prefix             = "${var.namespace}-secret-db-"
  description             = "Password to the RDS"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.default.result
}

resource "aws_db_instance" "wp_mysql" {
  identifier = "${var.namespace}-db"

  allocated_storage      = 20
  engine                 = local.rds.engine
  engine_version         = local.rds.engine_version
  instance_class         = local.rds.instance_class
  db_name                = local.rds.db_name
  username               = local.rds.username
  password               = aws_secretsmanager_secret_version.db.secret_string
  db_subnet_group_name   = aws_db_subnet_group.mission_db_group.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = true
  skip_final_snapshot    = true

  tags = {
    Name = "${var.namespace}-db"
  }
}