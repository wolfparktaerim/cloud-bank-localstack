resource "aws_security_group" "redis" {
  count       = var.enable_elasticache ? 1 : 0
  name        = "${var.project_name}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.lambda_security_group_id]
    description     = "Redis access from Lambda SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-redis-sg"
  })
}

resource "aws_elasticache_subnet_group" "redis" {
  count      = var.enable_elasticache ? 1 : 0
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-redis-subnet-group"
  })

  lifecycle {
    # LocalStack may omit persisted subnet IDs for ElastiCache subnet groups.
    ignore_changes = [subnet_ids]
  }
}

resource "aws_elasticache_cluster" "redis" {
  count = var.enable_elasticache ? 1 : 0

  cluster_id           = var.elasticache_cluster_id
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  subnet_group_name    = aws_elasticache_subnet_group.redis[0].name
  security_group_ids   = [aws_security_group.redis[0].id]

  tags = merge(var.tags, {
    Name = var.elasticache_cluster_id
  })

  lifecycle {
    # LocalStack may not return SG IDs on read even when configured.
    ignore_changes = [security_group_ids]
  }
}

resource "aws_iam_role" "glue" {
  count = var.enable_glue ? 1 : 0
  name  = "${var.project_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_glue_catalog_database" "main" {
  count = var.enable_glue ? 1 : 0
  name  = var.glue_database_name
}

resource "aws_glue_catalog_table" "transactions" {
  count         = var.enable_glue ? 1 : 0
  name          = var.glue_table_name
  database_name = aws_glue_catalog_database.main[0].name

  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = var.glue_s3_target_path
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json-serde"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "transaction_id"
      type = "string"
    }

    columns {
      name = "account_id"
      type = "string"
    }

    columns {
      name = "amount"
      type = "double"
    }
  }
}

resource "aws_glue_job" "etl" {
  count    = var.enable_glue ? 1 : 0
  name     = "${var.project_name}-etl-job"
  role_arn = aws_iam_role.glue[0].arn

  command {
    name            = "glueetl"
    script_location = "${var.glue_s3_target_path}/scripts/etl.py"
  }

  max_retries = 0
}

resource "aws_glue_crawler" "transactions" {
  count         = var.enable_glue ? 1 : 0
  name          = "${var.project_name}-transactions-crawler"
  database_name = aws_glue_catalog_database.main[0].name
  role          = aws_iam_role.glue[0].arn

  s3_target {
    path = var.glue_s3_target_path
  }
}
