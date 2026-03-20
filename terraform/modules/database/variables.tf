variable "project_name" { type = string }
variable "environment"  { type = string }
variable "tags"         { type = map(string) }

# Kept for documentation / future RDS upgrade, not used in LocalStack community
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "cloudbank"
}

variable "db_username" {
  type      = string
  sensitive = true
  default   = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "LocalDev123!"
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "vpc_id" {
  type    = string
  default = ""
}
