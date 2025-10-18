# CyberArk VSatellite Terraform Deployment

This Terraform configuration deploys a CyberArk VSatellite instance on AWS EC2 with automated installation and configuration using dynamic infrastructure discovery.

## Overview

VSatellite is a component of CyberArk's Machine Identity Security (MIS) platform that enables secure certificate management in hybrid and multi-cloud environments. This Terraform module:

- **Dynamically discovers** existing VPC and subnets using project tags
- Deploys an EC2 instance with the required specifications
- Automatically installs and configures VSatellite
- Sets up proper security groups and IAM roles
- **Uses AWS Session Manager** for secure access (no SSH keys needed)
- Configures CloudWatch logging
- Follows CyberArk's best practices and requirements

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Existing VPC and subnets** tagged with your project name
3. **CyberArk Tenant** with API access
4. **Terraform** >= 1.0
5. **AWS CLI** configured with credentials

## Infrastructure Requirements

Your AWS infrastructure should be tagged appropriately for discovery:

- **VPC**: Must have tag `Project = "your-project-name"`
- **Subnets**: Must have tag `Project = "your-project-name"`
- **Recommended**: Private subnets for enhanced security

## System Requirements Met

This configuration ensures VSatellite requirements are met:

- **Operating System**: Ubuntu 22.04 LTS (default) or Amazon Linux 2
- **RAM**: Minimum 4GB (t3.medium or larger)
- **CPUs**: Minimum 2 vCPUs
- **Disk Space**: 10GB+ free space with proper distribution
- **Root Privileges**: Configured via user data script
- **Network Access**: HTTPS outbound for CyberArk communication
- **Secure Access**: AWS Session Manager (no SSH keys required)

## Quick Start

1. **Clone or download** this Terraform configuration

2. **Copy the example variables file**:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** with your specific values:

   ```hcl
   project_name = "your-project-name"  # Used to find VPC and subnets
   environment = "dev"
   aws_region = "us-east-1"
   ```

4. **Initialize Terraform**:

   ```bash
   terraform init
   # Or use the alias: tfi
   ```

5. **Plan the deployment**:

   ```bash
   terraform plan
   ```

6. **Deploy the infrastructure**:
   ```bash
   terraform apply
   ```

## Configuration Options

### Infrastructure Discovery

- `project_name`: Project name used to find VPC and subnets by tag (required)
- `aws_region`: AWS region for deployment (default: us-east-1)
- `environment`: Environment name for resource naming (default: dev)

### Instance Configuration

- `instance_type`: EC2 instance type (default: t3.medium)
- `use_ubuntu`: Use Ubuntu instead of Amazon Linux (default: true)
- `root_volume_size`: Root EBS volume size in GB (default: 30)
- `create_data_volume`: Create additional data volume (default: true)

### Access and Security

- `associate_public_ip`: Associate public IP (default: false - not needed for Session Manager)
- `create_elastic_ip`: Create static Elastic IP (optional, default: false)
- **No SSH configuration needed** - uses AWS Session Manager

### VSatellite Options

- `use_install_dir_option`: Use consolidated installation directory (default: true)
- `vsatellite_install_dir`: Custom installation path (default: /opt/vsatellite)
- `vsatellite_version`: Specific version (leave empty for latest)

## Post-Deployment Steps

After successful deployment:

1. **Connect to the instance via AWS Session Manager**:

   - **AWS Console**: Go to Systems Manager > Session Manager > Start session
   - **Direct URL**: Use the `session_manager_connection` output from Terraform
   - **CLI**: Use AWS CLI with the instance ID from outputs

2. **Check installation status**:

   ```bash
   sudo cat /var/log/vsatellite-install.log
   sudo cat /var/log/vsatellite-status.json
   ```

3. **Configure VSatellite with CyberArk**:

   ```bash
   sudo vsatctl configure --api-key <your-api-key> --tenant-url <your-tenant-url>
   ```

4. **Verify VSatellite status**:
   ```bash
   sudo vsatctl status
   ```

## Security Considerations

- **Session Manager Access**: Secure browser-based terminal access, no SSH keys needed
- **Regional Restriction**: Session Manager access restricted to us-east-1 only
- **IAM Permissions**: Minimal permissions for CloudWatch and SSM
- **Encryption**: EBS volumes are encrypted by default
- **Security Groups**: Only necessary outbound ports (HTTPS, HTTP, DNS, NTP)
- **No Public IP**: Enhanced security with private networking
- **API Keys**: Can be stored securely in AWS SSM Parameter Store

## Monitoring and Logging

- **CloudWatch Logs**: Installation and container logs
- **Instance Monitoring**: Basic CloudWatch metrics
- **Status Tracking**: JSON status file for automation

## Troubleshooting

### Installation Issues

1. Check the installation log via Session Manager:

   ```bash
   sudo tail -f /var/log/vsatellite-install.log
   ```

2. Verify system requirements:

   ```bash
   sudo vsatctl preflight
   ```

3. Check Docker status:
   ```bash
   sudo systemctl status docker
   ```

### Infrastructure Discovery Issues

1. Verify your VPC and subnets are tagged correctly:

   ```bash
   aws ec2 describe-vpcs --filters "Name=tag:Project,Values=your-project-name"
   aws ec2 describe-subnets --filters "Name=tag:Project,Values=your-project-name"
   ```

2. Check Terraform outputs for discovered resources:
   ```bash
   terraform output discovered_vpc_id
   terraform output discovered_subnet_id
   ```

### Network Connectivity

1. Verify outbound HTTPS access:

   ```bash
   curl -I https://downloads.cyberark.com
   ```

2. Check security group rules:
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

### Session Manager Access

1. Ensure the instance has the SSM agent running:

   ```bash
   # Check from AWS Console: Systems Manager > Managed Instances
   ```

2. Verify IAM permissions for Session Manager access

### VSatellite Service

1. Check VSatellite status:

   ```bash
   sudo vsatctl status
   sudo vsatctl diagnostics
   ```

2. Restart VSatellite if needed:
   ```bash
   sudo vsatctl restart
   ```

## Outputs

The deployment provides useful outputs:

- `discovered_vpc_id`: VPC ID found by project tag
- `discovered_subnet_id`: Subnet ID found by project tag
- `instance_id`: EC2 instance ID
- `instance_private_ip`: Private IP address
- `session_manager_connection`: Instructions for Session Manager access
- `connection_info`: Complete connection details with Session Manager URL
- `vsatellite_install_directory`: Installation path
- `vsatellite_log_directory`: Log directory path

## Terraform Aliases

For convenience, you can use these aliases:

- `tfi` → `terraform init`
- Add more with: `alias tfp='terraform plan'`, `alias tfa='terraform apply'`

## Cleanup

To remove all resources:

```bash
terraform destroy
```

## Key Features Summary

🔍 **Dynamic Discovery**: Automatically finds VPC and subnets by project tags
🔒 **Secure Access**: AWS Session Manager (no SSH keys required)
🌍 **Regional Control**: Access restricted to us-east-1 only
📊 **Monitoring**: CloudWatch integration for logs and metrics
🔧 **Automated Setup**: Complete VSatellite installation via user data
🏗️ **Infrastructure**: Proper security groups, IAM roles, and encryption

## Support

For issues related to:

- **Terraform configuration**: Check this repository's issues
- **VSatellite installation**: Consult CyberArk documentation
- **AWS resources**: Review AWS service documentation

## License

This Terraform configuration is provided as-is. Please review and test thoroughly before production use.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Note**: This configuration follows CyberArk's official VSatellite system requirements and installation guidelines. Always refer to the latest CyberArk documentation for the most current requirements and procedures.
