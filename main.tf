# Terraform configuration for VSatellite deployment on EC2
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration for AWS
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
    }
  }
}

# Data source to get the existing VPC by project tag
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Project"
    values = [var.project_name]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Data source to get all subnets in the VPC with project tag
data "aws_subnets" "project_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Project"
    values = [var.project_name]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Select the first available subnet (you can modify this logic)
data "aws_subnet" "selected" {
  id = data.aws_subnets.project_subnets.ids[0]
}

# Data source to get existing security group by project and environment tags
data "aws_security_group" "existing" {
  filter {
    name   = "tag:Project"
    values = [var.project_name]
  }
  
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Data source for the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for Ubuntu 22.04 LTS AMI (alternative option)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role for VSatellite EC2 instance
resource "aws_iam_role" "vsatellite_role" {
  name = "${var.environment}-vsatellite-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for VSatellite operations (basic CloudWatch and SSM access)
resource "aws_iam_policy" "vsatellite_policy" {
  name        = "${var.environment}-vsatellite-policy"
  description = "IAM policy for VSatellite EC2 instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.environment}/vsatellite/*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "vsatellite_policy_attachment" {
  role       = aws_iam_role.vsatellite_role.name
  policy_arn = aws_iam_policy.vsatellite_policy.arn
}

# Attach AWS managed policy for SSM access
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.vsatellite_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM instance profile
resource "aws_iam_instance_profile" "vsatellite_profile" {
  name = "${var.environment}-vsatellite-profile"
  role = aws_iam_role.vsatellite_role.name
}

# EC2 Instance for VSatellite
resource "aws_instance" "vsatellite" {
  ami                         = var.use_ubuntu ? data.aws_ami.ubuntu.id : data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [data.aws_security_group.existing.id]
  # No key pair needed for Session Manager access
  iam_instance_profile        = aws_iam_instance_profile.vsatellite_profile.name
  associate_public_ip_address = var.enable_instance_connect ? true : var.associate_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    tags = merge(var.tags, {
      Name = "${var.environment}-vsatellite-root-volume"
    })
  }

  # Additional EBS volume for VSatellite data (optional)
  dynamic "ebs_block_device" {
    for_each = var.create_data_volume ? [1] : []
    content {
      device_name           = "/dev/sdf"
      volume_type           = "gp3"
      volume_size           = var.data_volume_size
      delete_on_termination = true
      encrypted             = true
      tags = merge(var.tags, {
        Name = "${var.environment}-vsatellite-data-volume"
      })
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    install_dir     = var.vsatellite_install_dir
    use_install_dir = var.use_install_dir_option
    environment     = var.environment
    use_ubuntu      = var.use_ubuntu
  }))

  tags = merge(var.tags, {
    Name = "${var.environment}-vsatellite"
  })

  lifecycle {
    create_before_destroy = false
  }
}

# Elastic IP (optional)
resource "aws_eip" "vsatellite_eip" {
  count    = var.create_elastic_ip ? 1 : 0
  instance = aws_instance.vsatellite.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.environment}-vsatellite-eip"
  })

  depends_on = [aws_instance.vsatellite]
}