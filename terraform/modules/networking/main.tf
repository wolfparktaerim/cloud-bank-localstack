# ─────────────────────────────────────────────
# Module: networking
# Owner: Member 1
# Layer: 1/2 (bootstrapped before security)
# Creates: VPC, subnets, IGW, NAT, route tables,
#          security groups
# ─────────────────────────────────────────────

# ── VPC ───────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.project_name}-vpc" })
}

# ── Subnets ───────────────────────────────────
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "ap-southeast-1${count.index == 0 ? "a" : "b"}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = "ap-southeast-1${count.index == 0 ? "a" : "b"}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

# ── Internet Gateway (public subnet outbound) ─
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.project_name}-igw" })
}

# ── Elastic IP + NAT Gateway ──────────────────
# NAT lives in public subnet — private subnets route through it
# for outbound internet (e.g. Lambda calling external APIs)
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = merge(var.tags, { Name = "${var.project_name}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id   # NAT must be in a PUBLIC subnet
  depends_on    = [aws_internet_gateway.main]
  tags          = merge(var.tags, { Name = "${var.project_name}-nat" })
}

# ── Route Tables ──────────────────────────────

# Public route table: 0.0.0.0/0 → Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table: 0.0.0.0/0 → NAT Gateway (outbound only)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, { Name = "${var.project_name}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── Security Groups ───────────────────────────

# ALB security group — internet-facing
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB: allow HTTPS inbound from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP (for redirect to HTTPS)"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-alb-sg" })
}

# Lambda security group — private, no inbound
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Lambda: no inbound, all outbound (Lambda initiates all connections)"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound (to RDS, Redis, AWS services)"
  }

  tags = merge(var.tags, { Name = "${var.project_name}-lambda-sg" })
}

# RDS security group — only accepts from Lambda
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS: PostgreSQL only from Lambda SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "PostgreSQL from Lambda only"
  }

  tags = merge(var.tags, { Name = "${var.project_name}-rds-sg" })
}

# Redis security group — only accepts from Lambda
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "ElastiCache Redis: only from Lambda SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "Redis from Lambda only"
  }

  tags = merge(var.tags, { Name = "${var.project_name}-redis-sg" })
}
