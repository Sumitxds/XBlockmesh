#!/bin/bash

# Function to display an error message and exit
error_exit() {
    echo "Error: $1"
    exit 1
}

# Update and upgrade system packages
echo "Updating and upgrading system packages..."
sudo apt update && sudo apt upgrade -y || error_exit "Failed to update and upgrade packages."

# Clean up old files
echo "Cleaning up old files..."
rm -rf block-mesh-manager-api.tar.gz target || error_exit "Failed to clean up old files."

# Function to install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release || error_exit "Failed to install required packages for Docker."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || error_exit "Failed to add Docker GPG key."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Failed to add Docker repository."
        sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io || error_exit "Failed to install Docker."
    else
        echo "Docker is already installed."
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        echo "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error_exit "Failed to download Docker Compose."
        sudo chmod +x /usr/local/bin/docker-compose || error_exit "Failed to set permissions for Docker Compose."
        command -v docker-compose &> /dev/null || error_exit "Docker Compose installation failed."
    else
        echo "Docker Compose is already installed."
    fi
}

# Function to download and extract BlockMesh Manager API
download_blockmesh_manager_api() {
    local version=${1:-"v0.0.418"}
    local url="https://github.com/block-mesh/block-mesh-monorepo/releases/download/${version}/block-mesh-manager-api-x86_64-unknown-linux-gnu.tar.gz"

    echo "Downloading and extracting BlockMesh Manager API (version: $version)..."
    mkdir -p target/release
    curl -L "$url" -o block-mesh-manager-api.tar.gz || error_exit "Failed to download BlockMesh Manager API."
    tar -xzf block-mesh-manager-api.tar.gz --strip-components=3 -C target/release || error_exit "Failed to extract BlockMesh Manager API."
    [[ -f target/release/block-mesh-manager-api ]] || error_exit "BlockMesh Manager API executable not found."
}

# Main script logic
install_docker
install_docker_compose
download_blockmesh_manager_api

# Prompt for email and password
read -p "Enter your BlockMesh email: " email
read -s -p "Enter your BlockMesh password: " password
echo

# Use BlockMesh Manager API to create a Docker container
echo "Creating Docker container for BlockMesh Manager API..."
sudo docker run -it --rm \
    --name block-mesh-manager-api-container \
    -v "$(pwd)/target/release:/app" \
    -e EMAIL="$email" \
    -e PASSWORD="$password" \
    --workdir /app \
    ubuntu:22.04 ./block-mesh-manager-api --email "$email" --password "$password" || error_exit "Failed to run the Docker container."
