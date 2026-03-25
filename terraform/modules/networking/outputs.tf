output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

# Phase 1: Subnet AZ cross-reference for multi-AZ validation
output "public_subnet_azs" {
  description = "Availability zones for public subnets (for multi-AZ validation)"
  value = {
    for idx, subnet in aws_subnet.public :
    subnet.id => subnet.availability_zone
  }
}

output "private_subnet_azs" {
  description = "Availability zones for private subnets (for multi-AZ validation)"
  value = {
    for idx, subnet in aws_subnet.private :
    subnet.id => subnet.availability_zone
  }
}

# Phase 1: Route Table outputs
output "public_route_table_id" {
  description = "Public route table for internet-routable traffic"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table for internal VPC traffic"
  value       = aws_route_table.private.id
}

# Phase 1: NACL outputs
output "public_network_acl_id" {
  description = "Public subnet NACL"
  value       = aws_network_acl.public.id
}

output "private_network_acl_id" {
  description = "Private subnet NACL"
  value       = aws_network_acl.private.id
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

# Phase 4A: RDS expects these for DB instance provisioning
output "db_subnet_ids" {
  description = "Private subnet IDs for RDS DB subnet group"
  value       = aws_subnet.private[*].id
}
