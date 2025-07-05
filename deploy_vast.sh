#!/bin/bash

# Forensic Audio Processing - One-Command Vast.ai Deployment
# Run this script on your Vast.ai instance to deploy the forensic audio tool

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              🔍 FORENSIC AUDIO PROCESSING v2.0               ║"
    echo "║                  Vast.ai Deployment Script                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner

print_status "Starting deployment on Vast.ai instance..."

# Check if running on a Vast.ai-like environment
if [ ! -d "/workspace" ] && [ ! -d "/root" ]; then
    print_warning "This doesn't look like a Vast.ai instance. Continuing anyway..."
fi

# Determine working directory
if [ -d "/workspace" ]; then
    WORK_DIR="/workspace"
elif [ -d "/root" ]; then
    WORK_DIR="/root"
else
    WORK_DIR="/tmp"
fi

PROJECT_DIR="$WORK_DIR/forensic-audio-app"

print_status "Working directory: $PROJECT_DIR"

# Check system requirements
print_status "Checking system requirements..."

# Check available memory
MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMORY_GB=$((MEMORY_KB / 1024 / 1024))

if [ "$MEMORY_GB" -lt 2 ]; then
    print_error "Insufficient memory! Need at least 2GB, found ${MEMORY_GB}GB"
    print_error "Try renting a Vast.ai instance with more RAM"
    exit 1
fi

# Check available disk space
DISK_GB=$(df -BG "$WORK_DIR" | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$DISK_GB" -lt 3 ]; then
    print_error "Insufficient disk space! Need at least 3GB, found ${DISK_GB}GB"
    exit 1
fi

print_success "System requirements met: ${MEMORY_GB}GB RAM, ${DISK_GB}GB disk"

# Update system packages
print_status "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1

# Install required packages
print_status "Installing required packages..."
apt-get install -y -qq git curl docker.io docker-compose > /dev/null 2>&1

# Start Docker service
print_status "Starting Docker service..."
service docker start > /dev/null 2>&1 || systemctl start docker > /dev/null 2>&1 || true

# Wait for Docker to be ready
sleep 3

# Clone the repository
print_status "Cloning forensic audio processing repository..."
if [ -d "$PROJECT_DIR" ]; then
    print_warning "Directory exists, removing old installation..."
    rm -rf "$PROJECT_DIR"
fi

git clone https://github.com/goharderr/forensic-audio-app.git "$PROJECT_DIR" > /dev/null 2>&1

if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Failed to clone repository!"
    exit 1
fi

cd "$PROJECT_DIR"

print_success "Repository cloned successfully"

# Create necessary directories
print_status "Setting up directories..."
mkdir -p temp logs

# Build and start the application
print_status "Building Docker image (this may take a few minutes)..."
docker-compose build > /dev/null 2>&1

if [ $? -ne 0 ]; then
    print_error "Docker build failed!"
    print_status "Trying alternative build method..."
    docker build -t forensic-audio . > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "All build methods failed. Check Docker installation."
        exit 1
    fi
fi

print_status "Starting the application..."
docker-compose up -d > /dev/null 2>&1

# Wait for application to start
print_status "Waiting for application to initialize..."
sleep 10

# Check if application is running
if curl -s -f http://localhost:8000/health > /dev/null 2>&1; then
    print_success "Application is running successfully!"
else
    print_warning "Application may still be starting up..."
    sleep 5
    if curl -s -f http://localhost:8000/health > /dev/null 2>&1; then
        print_success "Application is now running!"
    else
        print_error "Application failed to start properly"
        print_status "Checking logs..."
        docker-compose logs --tail=20
        exit 1
    fi
fi

# Get server information
HOSTNAME=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
if [ "$HOSTNAME" = "localhost" ] || [ -z "$HOSTNAME" ]; then
    HOSTNAME=$(curl -s http://ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
fi

# Success banner
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    🎉 DEPLOYMENT SUCCESSFUL! 🎉              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}🌐 Access your Forensic Audio Processing tool at:${NC}"
echo -e "   ${YELLOW}http://$HOSTNAME:8000${NC}"
echo ""
echo -e "${CYAN}🎚️ Available Audio Presets:${NC}"
echo -e "   ✨ Clean Whisper    - Minimal processing for clear enhancement"
echo -e "   🔧 Gentle Enhancement - Subtle improvements without artifacts"
echo -e "   👤 Whisper Mode     - Standard whisper enhancement (30-3500 Hz)"
echo -e "   📺 TV Suppression   - Background TV noise removal"
echo -e "   💨 Breath Detection - Optimized for respiratory sounds"
echo -e "   🎵 Vocal Isolation  - Enhanced for moans, grunts, vocals"
echo ""
echo -e "${CYAN}📊 Supported Files:${NC}"
echo -e "   • Audio: WAV, MP3, MP4, M4A, FLAC, OGG"
echo -e "   • Size: Up to 100MB+ (tested with 55MB files)"
echo -e "   • Duration: Up to hours (tested with 10-minute files)"
echo ""
echo -e "${CYAN}🔧 Management Commands:${NC}"
echo -e "   ${YELLOW}cd $PROJECT_DIR${NC}"
echo -e "   ${YELLOW}docker-compose logs -f${NC}         # View real-time logs"
echo -e "   ${YELLOW}docker-compose restart${NC}         # Restart application"
echo -e "   ${YELLOW}docker-compose down${NC}            # Stop application"
echo -e "   ${YELLOW}docker-compose up -d${NC}           # Start application"
echo ""
echo -e "${CYAN}📈 Performance:${NC}"
echo -e "   • Processing: 1-2 minutes for 10-minute files"
echo -e "   • Memory: ${MEMORY_GB}GB available"
echo -e "   • Storage: ${DISK_GB}GB available"
echo ""
echo -e "${CYAN}🔍 Health Check:${NC}"
echo -e "   ${YELLOW}curl http://localhost:8000/health${NC}"
echo ""
echo -e "${GREEN}Ready for forensic audio analysis! 🎵${NC}"

# Save connection info to file
cat > connection_info.txt << EOF
Forensic Audio Processing - Connection Information
Generated: $(date)

Web Interface: http://$HOSTNAME:8000
Project Directory: $PROJECT_DIR

Management Commands:
- View logs: docker-compose logs -f
- Restart: docker-compose restart  
- Stop: docker-compose down
- Start: docker-compose up -d

System Info:
- Memory: ${MEMORY_GB}GB
- Storage: ${DISK_GB}GB  
- Docker: $(docker --version 2>/dev/null || echo "Unknown")
EOF

print_status "Connection info saved to: $PROJECT_DIR/connection_info.txt"

# Optional: Show logs for a few seconds
if [ "${1:-}" = "--show-logs" ]; then
    echo ""
    print_status "Showing recent logs (press Ctrl+C to exit):"
    docker-compose logs -f --tail=20
fi
