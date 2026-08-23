output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs for the public subnets"
  value       = [aws_subnet.public_1a.id, aws_subnet.public_1b.id]
}

output "private_app_subnet_ids" {
  description = "List of IDs for the private application subnets"
  value       = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id]
}

output "isolated_db_subnet_ids" {
  description = "List of IDs for the isolated database subnets"
  value       = [aws_subnet.isolated_db_1a.id, aws_subnet.isolated_db_1b.id]
}

output "db_subnet_group_name" {
  description = "Name of the RDS DB subnet group"
  value       = aws_db_subnet_group.db_subnet_group.name
}

output "nat_gateway_public_ips" {
  description = "Public Elastic IPs of the NAT Gateways"
  value       = compact([aws_eip.nat_1a.public_ip, var.single_nat_gateway ? null : aws_eip.nat_1b[0].public_ip])
}

output "alb_security_group_id" {
  description = "Security Group ID for the Public ALB"
  value       = aws_security_group.alb_sg.id
}

output "app_security_group_id" {
  description = "Security Group ID for Private App Servers"
  value       = aws_security_group.app_sg.id
}

output "db_security_group_id" {
  description = "Security Group ID for Isolated Database"
  value       = aws_security_group.db_sg.id
}
