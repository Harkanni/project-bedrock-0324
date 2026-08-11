# --- DB Subnet Group ------------------------------------------------------
# Both RDS instances live in the private subnets — never publicly reachable.

resource "aws_db_subnet_group" "main" {
  name       = "project-bedrock-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "project-bedrock-db-subnet-group"
  }
}

# --- Security Group for RDS -------------------------------------------------
# Inbound DB traffic is allowed ONLY from the EKS cluster security group —
# not from a CIDR range, not from the internet. This is what EKS
# automatically attaches to both the control plane and worker nodes/pods
# when no custom node security group is specified, so it correctly scopes
# "traffic that is actually coming from the cluster."

resource "aws_security_group" "rds" {
  name        = "project-bedrock-rds-sg"
  description = "Allow DB traffic only from the EKS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EKS cluster"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "PostgreSQL from EKS cluster"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-bedrock-rds-sg"
  }
}

# --- Generated passwords ---------------------------------------------------
# Random, never hardcoded, never committed. Stored in Secrets Manager below.

resource "random_password" "mysql" {
  length  = 20
  special = false # avoids characters RDS/MySQL connection strings can choke on
}

resource "random_password" "postgres" {
  length  = 20
  special = false
}

# --- RDS: MySQL (Catalog service) -------------------------------------------

resource "aws_db_instance" "catalog_mysql" {
  identifier     = "project-bedrock-catalog-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type       = "gp3"

  db_name  = "catalog"
  username = "catalog_admin"
  password = random_password.mysql.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false # single-AZ per exam cost guidance
  publicly_accessible = false

  # Bonus 5.5: automated backups, non-zero retention.
  backup_retention_period = 1
  backup_window            = "03:00-04:00"

  skip_final_snapshot = true # acceptable for a course exam; not for real prod

  tags = {
    Name = "project-bedrock-catalog-mysql"
  }
}

# --- RDS: PostgreSQL (Orders service) ---------------------------------------

resource "aws_db_instance" "orders_postgres" {
  identifier     = "project-bedrock-orders-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type       = "gp3"

  db_name  = "orders"
  username = "orders_admin"
  password = random_password.postgres.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false

  backup_retention_period = 1
  backup_window            = "03:00-04:00"

  skip_final_snapshot = true

  tags = {
    Name = "project-bedrock-orders-postgres"
  }
}

# --- DynamoDB: Carts service -------------------------------------------------
# Schema confirmed directly from the app's source (DynamoItemEntity.java):
# partition key is "id" (one row per cart item), with a global secondary
# index on "customerId" for cart lookups — NOT customerId as the table's
# own partition key, which is what this was originally (incorrectly) built with.

resource "aws_dynamodb_table" "carts" {
  name         = "project-bedrock-carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "customerId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx_global_customerId" # exact name the app queries by — confirmed from source
    hash_key        = "customerId"
    projection_type = "ALL"
  }

  tags = {
    Name = "project-bedrock-carts"
  }
}

# --- Secrets Manager: DB credentials -----------------------------------------
# Application reads these at runtime via IRSA (IAM Roles for Service
# Accounts) — never injected as plaintext Helm values or committed to git.

resource "aws_secretsmanager_secret" "mysql" {
  name = "project-bedrock/catalog-mysql"
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({
    username = aws_db_instance.catalog_mysql.username
    password = random_password.mysql.result
    host     = aws_db_instance.catalog_mysql.address
    port     = aws_db_instance.catalog_mysql.port
    dbname   = aws_db_instance.catalog_mysql.db_name
  })
}

resource "aws_secretsmanager_secret" "postgres" {
  name = "project-bedrock/orders-postgres"
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({
    username = aws_db_instance.orders_postgres.username
    password = random_password.postgres.result
    host     = aws_db_instance.orders_postgres.address
    port     = aws_db_instance.orders_postgres.port
    dbname   = aws_db_instance.orders_postgres.db_name
  })
}
