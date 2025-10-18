# Outputs for VSatellite Terraform deployment

# Discovered infrastructure
output "discovered_vpc_id" {
  description = "ID of the VPC found by project tag"
  value       = data.aws_vpc.existing.id
}

output "discovered_subnet_id" {
  description = "ID of the subnet found by project tag"
  value       = data.aws_subnet.selected.id
}

output "instance_id" {
  description = "ID of the VSatellite EC2 instance"
  value       = aws_instance.vsatellite.id
}

output "instance_arn" {
  description = "ARN of the VSatellite EC2 instance"
  value       = aws_instance.vsatellite.arn
}

output "instance_public_ip" {
  description = "Public IP address of the VSatellite instance"
  value       = aws_instance.vsatellite.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the VSatellite instance"
  value       = aws_instance.vsatellite.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the VSatellite instance"
  value       = aws_instance.vsatellite.public_dns
}

output "instance_private_dns" {
  description = "Private DNS name of the VSatellite instance"
  value       = aws_instance.vsatellite.private_dns
}

output "elastic_ip" {
  description = "Elastic IP address (if created)"
  value       = var.create_elastic_ip ? aws_eip.vsatellite_eip[0].public_ip : null
}

output "elastic_ip_allocation_id" {
  description = "Allocation ID of the Elastic IP (if created)"
  value       = var.create_elastic_ip ? aws_eip.vsatellite_eip[0].allocation_id : null
}

output "security_group_id" {
  description = "ID of the existing security group used by VSatellite (found by Project and Environment tags)"
  value       = data.aws_security_group.existing.id
}

output "security_group_arn" {
  description = "ARN of the existing security group used by VSatellite (found by Project and Environment tags)"
  value       = data.aws_security_group.existing.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.vsatellite_role.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.vsatellite_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.vsatellite_profile.name
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.vsatellite_profile.arn
}

# SSH-related outputs removed - using Session Manager for access

output "session_manager_connection" {
  description = "Instructions for connecting via Session Manager"
  value       = "Use AWS Console Systems Manager > Session Manager to connect to instance ${aws_instance.vsatellite.id}"
}

output "vsatellite_install_directory" {
  description = "VSatellite installation directory"
  value       = var.use_install_dir_option ? var.vsatellite_install_dir : "/var/lib/rancher"
}

output "vsatellite_log_directory" {
  description = "VSatellite log directory"
  value       = var.use_install_dir_option ? "${var.vsatellite_install_dir}/vsatellite/logs" : "/var/log/containers"
}

# CloudWatch Log Group information
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for VSatellite logs"
  value       = "/aws/ec2/${var.environment}/vsatellite"
}

# Connection information
output "connection_info" {
  description = "Connection information for the VSatellite instance"
  value = {
    instance_id         = aws_instance.vsatellite.id
    private_ip          = aws_instance.vsatellite.private_ip
    access_methods      = var.enable_instance_connect ? ["AWS Session Manager", "EC2 Instance Connect"] : ["AWS Session Manager"]
    security_group      = data.aws_security_group.existing.id
    session_manager_url = "https://console.aws.amazon.com/systems-manager/session-manager/${aws_instance.vsatellite.id}"
    instance_connect_url = var.enable_instance_connect ? "https://console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#ConnectToInstance:instanceId=${aws_instance.vsatellite.id}" : null
  }
}

output "instance_connect_info" {
  description = "EC2 Instance Connect information"
  value = var.enable_instance_connect ? {
    enabled = true
    console_url = "https://console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#ConnectToInstance:instanceId=${aws_instance.vsatellite.id}"
    cli_command = "aws ec2-instance-connect send-ssh-public-key --region ${var.aws_region} --instance-id ${aws_instance.vsatellite.id} --availability-zone ${aws_instance.vsatellite.availability_zone} --instance-os-user ubuntu --ssh-public-key file://~/.ssh/id_rsa.pub"
    ssh_user = var.use_ubuntu ? "ubuntu" : "ec2-user"
  } : {
    enabled = false
    message = "Instance Connect is disabled. Enable with enable_instance_connect = true"
  }
}