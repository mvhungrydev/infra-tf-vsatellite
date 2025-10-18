# Variables for VSatellite Terraform deployment

variable "project_name" {
  description = "Name of the project (used to find VPC and subnets by tag)"
  type        = string
  default     = "terraform-cicd"
}
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type for VSatellite. m7i-flex.large is Free Tier eligible and meets all VSatellite requirements (8GB RAM, 2 vCPUs)"
  type        = string
  default     = "m7i-flex.large"
  validation {
    condition = contains([
      "t2.micro", "t2.small", "t2.medium",
      "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
      "m6i.large", "m6i.xlarge", "m6i.2xlarge", "m6i.4xlarge",
      "m7i-flex.large", "m7i-flex.xlarge", "m7i-flex.2xlarge"
    ], var.instance_type)
    error_message = "Instance type must be valid. For production use, ensure instance meets VSatellite requirements (4GB RAM, 2 vCPUs)."
  }
}

variable "use_ubuntu" {
  description = "Use Ubuntu 22.04 LTS instead of Amazon Linux 2"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.root_volume_size >= 15
    error_message = "Root volume must be at least 15 GB for VSatellite and OS."
  }
}

variable "create_data_volume" {
  description = "Create an additional EBS volume for VSatellite data"
  type        = bool
  default     = false
}

variable "data_volume_size" {
  description = "Size of the additional data EBS volume in GB"
  type        = number
  default     = 50
}

variable "associate_public_ip" {
  description = "Associate a public IP address with the instance (not needed for Session Manager, but required for Instance Connect)"
  type        = bool
  default     = false
}

variable "enable_instance_connect" {
  description = "Enable EC2 Instance Connect for SSH access through AWS console (automatically enables public IP)"
  type        = bool
  default     = true
}

variable "create_elastic_ip" {
  description = "Create and associate an Elastic IP address"
  type        = bool
  default     = false
}

# SSH-related variables removed - using Session Manager for access

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default = {
    Project     = "VSatellite"
  }
}

# VSatellite specific variables
variable "vsatellite_version" {
  description = "Version of VSatellite to install (latest if empty)"
  type        = string
  default     = ""
}

variable "use_install_dir_option" {
  description = "Use --install-dir option to consolidate VSatellite installation"
  type        = bool
  default     = true
}

variable "vsatellite_install_dir" {
  description = "Custom installation directory for VSatellite (when use_install_dir_option is true)"
  type        = string
  default     = "/opt/vsatellite"
  validation {
    condition     = can(regex("^/[a-zA-Z0-9_/-]+$", var.vsatellite_install_dir))
    error_message = "Install directory must be an absolute path."
  }
}

variable "vsatellite_api_key" {
  description = "CyberArk API key for VSatellite registration (will be stored in SSM Parameter Store)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vsatellite_name" {
  description = "Name for the VSatellite instance in CyberArk console"
  type        = string
  default     = ""
}

variable "cyberark_tenant_url" {
  description = "CyberArk tenant URL (e.g., https://api.venafi.cloud)"
  type        = string
  default     = "https://api.venafi.cloud"
}

# Network and security variables
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for the instance"
  type        = bool
  default     = false
}

variable "enable_termination_protection" {
  description = "Enable termination protection for the instance"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}