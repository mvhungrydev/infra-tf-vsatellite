#!/bin/bash
# VSatellite Prerequisites Setup Script
# Sets up drive spaces and installs necessary prerequisites for VSatellite

set -e

# Variables passed from Terraform
INSTALL_DIR="${install_dir}"
USE_INSTALL_DIR="${use_install_dir}"
ENVIRONMENT="${environment}"
USE_UBUNTU="${use_ubuntu}"

# Logging
exec > >(tee /var/log/vsatellite-setup.log)
exec 2>&1

echo "=== VSatellite Prerequisites Setup Started at $(date) ==="
echo "Environment: $ENVIRONMENT"
echo "Using Ubuntu: $USE_UBUNTU"
echo "Install Directory: $INSTALL_DIR"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Setup additional drive space if data volume exists
setup_drives() {
    log "Setting up drive spaces..."
    
    # Check if additional data volume exists (/dev/sdf or /dev/nvme1n1)
    if [ -b "/dev/sdf" ]; then
        DATA_DEVICE="/dev/sdf"
    elif [ -b "/dev/nvme1n1" ]; then
        DATA_DEVICE="/dev/nvme1n1"
    else
        log "No additional data volume found, using root volume only"
        return 0
    fi
    
    log "Found additional data volume: $DATA_DEVICE"
    
    # Create filesystem if not already formatted
    if ! blkid "$DATA_DEVICE"; then
        log "Formatting data volume with ext4..."
        mkfs.ext4 "$DATA_DEVICE"
    fi
    
    # Create mount point and mount
    mkdir -p /opt/vsatellite-data
    mount "$DATA_DEVICE" /opt/vsatellite-data
    
    # Add to fstab for persistent mounting
    UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
    if ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID /opt/vsatellite-data ext4 defaults,nofail 0 2" >> /etc/fstab
    fi
    
    # Set permissions
    chmod 755 /opt/vsatellite-data
    
    log "Data volume mounted at /opt/vsatellite-data"
}

# Create VSatellite directories
setup_directories() {
    log "Setting up VSatellite directories..."
    
    # Create main installation directory
    if [ "$USE_INSTALL_DIR" = "true" ] && [ -n "$INSTALL_DIR" ]; then
        log "Creating installation directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
        chmod 755 "$INSTALL_DIR"
    fi
    
    # Create standard directories
    mkdir -p /opt/vsatellite
    mkdir -p /var/log/vsatellite
    mkdir -p /etc/vsatellite
    
    # Set proper permissions
    chmod 755 /opt/vsatellite
    chmod 755 /var/log/vsatellite
    chmod 750 /etc/vsatellite
    
    log "Directories created successfully"
}

# Update system and install prerequisites
install_prerequisites() {
    log "Installing prerequisites..."
    
    if [ "$USE_UBUNTU" = "true" ]; then
        # Ubuntu
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get upgrade -y
        
        # Install essential packages
        apt-get install -y \
            curl \
            wget \
            unzip \
            jq \
            ca-certificates \
            gnupg \
            lsb-release \
            software-properties-common \
            apt-transport-https \
            net-tools \
            htop \
            vim
    else
        # Amazon Linux 2
        yum update -y
        
        # Install essential packages
        yum install -y \
            curl \
            wget \
            unzip \
            jq \
            ca-certificates \
            openssl \
            tar \
            gzip \
            net-tools \
            htop \
            vim
    fi
    
    log "Prerequisites installed successfully"
}



# Download vsatctl
install_vsatctl() {
    log "Downloading vsatctl..."
    
    # Download vsatctl from official Venafi source to tmp folder
    cd /tmp
    curl -O https://dl.venafi.cloud/vsatctl
    
    if [ $? -eq 0 ] && [ -f "vsatctl" ]; then
        # Make executable
        chmod +x vsatctl
        
        # Verify download
        if [ -x "/tmp/vsatctl" ]; then
            log "vsatctl downloaded successfully to /tmp/vsatctl"
            /tmp/vsatctl version 2>/dev/null || log "vsatctl downloaded but version check failed"
        else
            log "ERROR: vsatctl download failed"
            exit 1
        fi
    else
        log "ERROR: Failed to download vsatctl from https://dl.venafi.cloud/vsatctl"
        log "Please check internet connectivity and try manual download"
        exit 1
    fi
}

# Configure system for VSatellite
configure_system() {
    log "Configuring system for VSatellite..."
    
    # Configure file limits
    cat >> /etc/security/limits.conf << EOF

# VSatellite system limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

    # Configure kernel parameters
    cat >> /etc/sysctl.conf << EOF

# VSatellite kernel parameters
net.ipv4.ip_forward = 1
vm.swappiness = 1
vm.overcommit_memory = 1
EOF
    
    sysctl -p
    
    log "System configured for VSatellite"
}

# Create setup status file
create_status() {
    log "Creating setup status file..."
    
    # Check disk space
    ROOT_SPACE=$(df -h / | awk 'NR==2 {print $4}')
    DATA_SPACE="N/A"
    if mountpoint -q /opt/vsatellite-data; then
        DATA_SPACE=$(df -h /opt/vsatellite-data | awk 'NR==2 {print $4}')
    fi
    
    cat > /var/log/vsatellite-setup-status.json << EOF
{
    "setup_date": "$(date -Iseconds)",
    "environment": "$ENVIRONMENT",
    "os_type": "$([ "$USE_UBUNTU" = "true" ] && echo "ubuntu" || echo "amazon-linux")",
    "install_directory": "$INSTALL_DIR",
    "vsatctl_downloaded": "$([ -x "/tmp/vsatctl" ] && echo "yes" || echo "no")",
    "vsatctl_location": "/tmp/vsatctl",
    "vsatctl_version": "$(/tmp/vsatctl version 2>/dev/null || echo 'not available')",
    "root_disk_available": "$ROOT_SPACE",
    "data_disk_available": "$DATA_SPACE",
    "status": "prerequisites_ready"
}
EOF
    
    log "Setup status saved to /var/log/vsatellite-setup-status.json"
}

# Main setup process
main() {
    log "Starting VSatellite prerequisites setup..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi
    
    # Run setup steps
    setup_drives
    setup_directories
    install_prerequisites
    install_vsatctl
    configure_system
    create_status
    
    log "VSatellite prerequisites setup completed successfully!"
    log ""
    log "=== SETUP SUMMARY ==="
    log "DONE: Drive spaces configured"
    log "DONE: VSatellite directories created"
    log "DONE: Prerequisites installed"
    log "DONE: vsatctl downloaded to /tmp/vsatctl"
    log "DONE: System configured for VSatellite"
    log ""
    log "Next steps:"
    log "1. Run preflight checks: /tmp/vsatctl preflight"
    log "2. Install VSatellite: /tmp/vsatctl install"
    log "3. Configure VSatellite with your Venafi credentials"
    log "4. Register the VSatellite with your Venafi tenant"
    log ""
    log "Status file: /var/log/vsatellite-setup-status.json"
    log "Log file: /var/log/vsatellite-setup.log"
    
    echo "=== VSatellite Prerequisites Setup Completed at $(date) ==="
}

# Run main function
main "$@"