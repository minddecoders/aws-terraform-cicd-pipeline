# INFRASTRUCTURE OUTPUT DATA
# ==========================================

output "vpc_id" {
  value       = aws_vpc.sidra_automated_vpc.id
  description = "The unique identifier of the created VPC"
}

output "public_web_server_url" {
  value       = "http://${aws_instance.ssm_vm.public_ip}"
  description = "The live public web URL for the Nginx storefront server"
}

output "public_instance_id" {
  value       = aws_instance.ssm_vm.id
  description = "The core instance tracking ID for the public SSM node"
}

output "private_instance_internal_ip" {
  value       = aws_instance.ssm_private_vm.private_ip
  description = "The non-routable interior private IP of the dark database tier"
}

output "private_instance_id" {
  value       = aws_instance.ssm_private_vm.id
  description = "The core instance tracking ID for the backend isolated node"
}
