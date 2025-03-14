#!/bin/bash

# MiroTalk SFU Service Manager
# A clean, focused tool for managing your MiroTalk SFU instance

APP_PATH="/home/nightfury/selfhosted/mirotalksfu"
SERVICE_NAME="mirotalksfu"
HOSTNAME="meet.hbqnexus.win"
PORT=3055

# ====================================
# Utility Functions
# ====================================

print_header() {
    clear
    echo "=============================================="
    echo "     MiroTalk SFU - Service Manager     "
    echo "=============================================="
    echo ""
}

show_status() {
    echo -e "\n=== Service Status ==="
    systemctl status $SERVICE_NAME --no-pager
    echo -e "\nPress Enter to continue..."
    read
}

# ====================================
# Core Service Functions
# ====================================

start_service() {
    echo "🟢 Starting MiroTalk SFU service..."
    sudo systemctl start $SERVICE_NAME
    echo "✅ Service started!"
    show_status
}

stop_service() {
    echo "🔴 Stopping MiroTalk SFU service..."
    sudo systemctl stop $SERVICE_NAME
    echo "✅ Service stopped!"
    show_status
}

restart_service() {
    echo "🔄 Restarting MiroTalk SFU service with latest updates..."
    
    # Navigate to app directory
    cd $APP_PATH
    
    # Stop the service
    sudo systemctl stop $SERVICE_NAME
    
    # Get the current branch
    CURRENT_BRANCH=$(git branch --show-current)
    echo "📌 Current branch: $CURRENT_BRANCH"
    
    # Pull the latest changes
    echo "📥 Pulling latest updates from git..."
    git pull
    
    # Install any new dependencies
    echo "📦 Checking for new dependencies..."
    npm install
    
    # Start the service again
    sudo systemctl start $SERVICE_NAME
    
    echo "✅ Service restarted with latest updates!"
    show_status
}

view_logs() {
    echo -e "\n=== MiroTalk SFU Logs ==="
    PS3=$'\n'"Select a log option: "
    options=(
        "Recent logs (last 50 entries)"
        "Error logs only"
        "Live log follow (Ctrl+C to exit)"
        "Return to main menu"
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "Recent logs (last 50 entries)")
                sudo journalctl -u $SERVICE_NAME -n 50 --no-pager
                break
                ;;
            "Error logs only)")
                sudo journalctl -u $SERVICE_NAME -p err -n 50 --no-pager
                break
                ;;
            "Live log follow (Ctrl+C to exit)")
                echo "⚠️ Press Ctrl+C to stop following logs"
                sleep 2
                sudo journalctl -u $SERVICE_NAME -f
                break
                ;;
            "Return to main menu")
                break
                ;;
            *)
                echo "❌ Invalid option"
                ;;
        esac
    done
    
    echo -e "\nPress Enter to continue..."
    read
}

# ====================================
# Setup Functions
# ====================================

setup_service() {
    echo -e "\n=== Setting up MiroTalk SFU Service ==="
    
    # Check if service already exists
    if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        echo "⚠️ Service already exists. Do you want to overwrite it? (y/n)"
        read overwrite
        if [[ "$overwrite" != "y" ]]; then
            echo "🛑 Setup cancelled."
            return
        fi
    fi
    
    echo "🔧 Creating optimized systemd service for i7-12700..."
    
    # Create service file
    cat > /tmp/$SERVICE_NAME.service << EOF
[Unit]
Description=MiroTalk SFU Service
After=network.target
Wants=network-online.target
# Add dependency on display manager for hardware acceleration
After=display-manager.service

[Service]
Type=simple
User=nightfury
WorkingDirectory=$APP_PATH
# Environment variables
Environment=PORT=$PORT
Environment=NODE_ENV=production
# Hardware acceleration for Intel (improved settings for 12th gen)
Environment=LIBVA_DRIVER_NAME=iHD
Environment=LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
# Force Intel GPU for encoding/decoding
Environment=INTEL_GPU_TOP=1
Environment=VDPAU_DRIVER=va_gl
# Enable hardware acceleration in Chromium-based browsers
Environment=CHROME_FLAGS="--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization --enable-gpu-rasterization --enable-zero-copy"
# Enable more detailed logging if needed
# Environment=DEBUG="mediasoup:*"
# Force AV1 codec in supported browsers
Environment=ENABLE_AV1=1

# CPU and process scheduling optimizations
# Run with high priority (-20 is highest, 19 is lowest)
Nice=-15
# Real-time I/O priority
IOSchedulingClass=1
IOSchedulingPriority=0
# Use FIFO scheduling policy for real-time performance
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=90
# Optimized for 12th Gen Intel - use P-cores (first 8 cores are P-cores on i7-12700)
# This ensures compute-intensive tasks run on P-cores rather than E-cores
CPUAffinity=0-7

# Memory optimizations
# Lock process in memory to prevent swapping
MemoryDenyWriteExecute=no
LockPersonality=yes
MemoryLock=yes

# Set resource limits
LimitNOFILE=1000000
LimitNPROC=1000000

# 1. First, set CPU governor with sudo (runs as root)
ExecStartPre=/bin/bash -c "sudo sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'"
# Ensure large UDP buffer sizes
ExecStartPre=/bin/bash -c "sudo sysctl -w net.core.rmem_max=16777216 net.core.wmem_max=16777216"

# Start command with optimized Node.js flags for media server
ExecStart=/usr/bin/node --max-old-space-size=49152 --expose-gc --optimize-for-size --max-http-header-size=32768 --max-semi-space-size=512 --v8-pool-size=8 --nouse-idle-notification --max-http-header-size=81920 app/src/Server.js

# Restart configuration
Restart=always
RestartSec=5
# Give the service more time to stop gracefully
TimeoutStopSec=30

# Security enhancements (comment out if causing issues)
# ProtectSystem=strict
# PrivateTmp=true
# RestrictRealtime=false
# RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

[Install]
WantedBy=multi-user.target
EOF
    
    # Install the service
    sudo mv /tmp/$SERVICE_NAME.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    
    # Setup sudo permissions for CPU governor management
    echo "🔧 Setting up sudo permissions for CPU governor management..."
    
    cat > /tmp/mirotalksfu << EOF
nightfury ALL=(ALL) NOPASSWD: /bin/sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
nightfury ALL=(ALL) NOPASSWD: /usr/sbin/sysctl -w net.core.rmem_max=16777216 net.core.wmem_max=16777216
EOF
    
    sudo mv /tmp/mirotalksfu /etc/sudoers.d/
    sudo chmod 0440 /etc/sudoers.d/mirotalksfu
    
    echo "✅ Service setup complete!"
    echo "📝 You can now start the service with: sudo systemctl start $SERVICE_NAME"
    
    echo -e "\n⚠️ Do you want to apply the optimized configuration for 4K streaming? (y/n)"
    read apply_config
    
    if [[ "$apply_config" == "y" ]]; then
        extract_and_apply_config
    fi
    
    echo -e "\nPress Enter to continue..."
    read
}

# ====================================
# Configuration Functions
# ====================================

extract_custom_config() {
    echo "🔍 Analyzing current configuration..."
    
    # Check if config.js exists
    if [ ! -f "$APP_PATH/app/src/config.js" ]; then
        echo "❌ Error: config.js not found. Cannot extract custom configuration."
        return 1
    fi
    
    # Create a temp directory
    TEMP_DIR=$(mktemp -d)
    
    # Create a diff file between config.template.js and config.js
    diff -u "$APP_PATH/app/src/config.template.js" "$APP_PATH/app/src/config.js" > "$TEMP_DIR/config.diff"
    
    if [ $? -eq 0 ]; then
        echo "⚠️ No differences found between template and current config."
        rm -rf $TEMP_DIR
        return 0
    fi
    
    echo "✅ Found custom configuration settings:"
    grep -E "^[+]" "$TEMP_DIR/config.diff" | grep -v "^+++" | sed 's/^+//' | grep -v "^$"
    
    # Save important sections
    echo "📋 Extracting key configuration settings..."
    
    # Extract IPv4 setting
    IPV4_SETTING=$(grep -E "^[+]const IPv4" "$TEMP_DIR/config.diff" | sed 's/^+//')
    
    # Extract media codec settings
    MEDIA_CODEC_SETTINGS=$(grep -E "^[+].*google.*bitrate" "$TEMP_DIR/config.diff" | sed 's/^+//')
    
    # Extract screen sharing settings
    SCREEN_SETTINGS=$(grep -E "^[+].*screenSharingSettings" -A 5 "$TEMP_DIR/config.diff" | sed 's/^+//')
    
    # Extract WebRTC transport settings
    TRANSPORT_SETTINGS=$(grep -E "^[+].*initialAvailableOutgoingBitrate|^[+].*minimumAvailableOutgoingBitrate|^[+].*maxIncomingBitrate" "$TEMP_DIR/config.diff" | sed 's/^+//')
    
    # Store extracted settings for later use
    echo "$IPV4_SETTING" > "$TEMP_DIR/ipv4.setting"
    echo "$MEDIA_CODEC_SETTINGS" > "$TEMP_DIR/codec.setting"
    echo "$SCREEN_SETTINGS" > "$TEMP_DIR/screen.setting"
    echo "$TRANSPORT_SETTINGS" > "$TEMP_DIR/transport.setting"
    
    echo "✅ Configuration extracted to $TEMP_DIR"
    return 0
}

apply_custom_config() {
    echo "🔧 Applying optimized configuration for 4K streaming..."
    
    # Check if config.js exists, if not copy from template
    if [ ! -f "$APP_PATH/app/src/config.js" ]; then
        echo "⚠️ Creating config.js from template..."
        cp "$APP_PATH/app/src/config.template.js" "$APP_PATH/app/src/config.js"
    fi
    
    # Backup current config
    cp "$APP_PATH/app/src/config.js" "$APP_PATH/app/src/config.js.bak.$(date +%Y%m%d%H%M%S)"
    echo "💾 Backed up current config.js"
    
    # Apply optimized 4K settings
    
    # Optimize IPv4 setting - keep current setting if exists
    CURRENT_IPV4=$(grep -E "const IPv4 = " "$APP_PATH/app/src/config.js" | sed "s/const IPv4 = //")
    if [ -n "$CURRENT_IPV4" ]; then
        echo "📌 Keeping current IPv4 setting: $CURRENT_IPV4"
    fi
    
    # Update video codec parameters for 4K
    echo "🎬 Optimizing video codec parameters for 4K..."
    sed -i "/video\/VP8/,/},/ s/'x-google-start-bitrate': [0-9]*,/'x-google-start-bitrate': 1000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/VP8/,/},/ s/'x-google-min-bitrate': [0-9]*,/'x-google-min-bitrate': 15000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/VP8/,/},/ s/'x-google-max-bitrate': [0-9]*,/'x-google-max-bitrate': 100000000,/" "$APP_PATH/app/src/config.js"
    
    # Update VP9 settings
    sed -i "/video\/VP9.*profile-id': 2/,/},/ s/'x-google-start-bitrate': [0-9]*,/'x-google-start-bitrate': 3000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/VP9.*profile-id': 2/,/},/ s/'x-google-min-bitrate': [0-9]*,/'x-google-min-bitrate': 18000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/VP9.*profile-id': 2/,/},/ s/'x-google-max-bitrate': [0-9]*,/'x-google-max-bitrate': 150000000,/" "$APP_PATH/app/src/config.js"
    
    # Update H264 settings
    sed -i "/video\/h264.*profile-level-id': '640032/,/},/ s/'x-google-start-bitrate': [0-9]*,/'x-google-start-bitrate': 2000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/h264.*profile-level-id': '640032/,/},/ s/'x-google-min-bitrate': [0-9]*,/'x-google-min-bitrate': 15000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/h264.*profile-level-id': '640032/,/},/ s/'x-google-max-bitrate': [0-9]*,/'x-google-max-bitrate': 150000000,/" "$APP_PATH/app/src/config.js"
    
    # Update baseline H264 settings
    sed -i "/video\/h264.*profile-level-id': '42e01f/,/},/ s/'x-google-start-bitrate': [0-9]*,/'x-google-start-bitrate': 1000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/h264.*profile-level-id': '42e01f/,/},/ s/'x-google-min-bitrate': [0-9]*,/'x-google-min-bitrate': 15000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/video\/h264.*profile-level-id': '42e01f/,/},/ s/'x-google-max-bitrate': [0-9]*,/'x-google-max-bitrate': 150000000,/" "$APP_PATH/app/src/config.js"
    
    # Update WebRTC transport settings
    echo "🌐 Optimizing WebRTC transport settings..."
    sed -i "/webRtcTransport/,/initialAvailableOutgoingBitrate/ s/initialAvailableOutgoingBitrate: [0-9]*,/initialAvailableOutgoingBitrate: 500000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/webRtcTransport/,/minimumAvailableOutgoingBitrate/ s/minimumAvailableOutgoingBitrate: [0-9]*,/minimumAvailableOutgoingBitrate: 150000000,/" "$APP_PATH/app/src/config.js"
    sed -i "/webRtcTransport/,/maxIncomingBitrate/ s/maxIncomingBitrate: [0-9]*,/maxIncomingBitrate: 500000000,/" "$APP_PATH/app/src/config.js"
    
    # Update screen sharing settings
    echo "🖥️ Optimizing screen sharing for 4K @ 60fps..."
    sed -i "/screenSharingSettings/,/frameRate/ s/frameRate: [0-9]*,/frameRate: 60,/" "$APP_PATH/app/src/config.js"
    sed -i "/screenSharingSettings/,/maxBitrate/ s/maxBitrate: [0-9]*,/maxBitrate: 220000000,/" "$APP_PATH/app/src/config.js"
    
    echo "✅ Applied 4K optimized configuration!"
    echo "⚠️ You may need to restart the service to apply the changes."
}

extract_and_apply_config() {
    echo "🔄 Extracting current config and applying optimized settings..."
    
    # Backup current config
    if [ -f "$APP_PATH/app/src/config.js" ]; then
        cp "$APP_PATH/app/src/config.js" "$APP_PATH/app/src/config.js.bak.$(date +%Y%m%d%H%M%S)"
        echo "💾 Backed up current config.js"
    else
        echo "⚠️ No existing config.js found. Will create a new one."
    }
    
    # Extract current custom settings if they exist
    if [ -f "$APP_PATH/app/src/config.js" ]; then
        extract_custom_config
    fi
    
    # Apply optimized config for 4K
    apply_custom_config
    
    echo "✅ Configuration updated successfully!"
}

# ====================================
# Performance Optimization
# ====================================

optimize_for_4k() {
    echo -e "\n=== Hardware Analysis & 4K Optimization ==="
    
    # Check CPU
    echo "🔍 Checking CPU..."
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^[ \t]*//')
    CPU_CORES=$(lscpu | grep "^CPU(s):" | cut -d: -f2 | sed 's/^[ \t]*//')
    
    echo "CPU: $CPU_MODEL"
    echo "Cores: $CPU_CORES"
    
    # Check RAM
    echo -e "\n🔍 Checking memory..."
    MEM_TOTAL=$(free -h | grep "Mem:" | awk '{print $2}')
    echo "Total memory: $MEM_TOTAL"
    
    # Check disk
    echo -e "\n🔍 Checking disk space..."
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    echo "Free space: $DISK_FREE"
    
    # Check network
    echo -e "\n🔍 Checking network interfaces..."
    ip -o addr show | grep 'inet ' | awk '{print $2, $4}' | sed 's/\/.*//'
    
    # Show current system settings
    echo -e "\n📊 Current system settings:"
    echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
    echo "UDP Buffer Size: $(sysctl net.core.rmem_max | awk '{print $3}')"
    
    echo -e "\n📋 Recommended optimizations:"
    
    # Build list of recommendations
    RECOMMENDATIONS=()
    
    RECOMMENDATIONS+=("Set CPU governor to performance mode")
    RECOMMENDATIONS+=("Optimize network buffers for WebRTC traffic")
    RECOMMENDATIONS+=("Update MiroTalk config for 4K @ 60fps")
    
    # Display recommendations
    for i in "${!RECOMMENDATIONS[@]}"; do
        echo " $((i+1)). ${RECOMMENDATIONS[$i]}"
    done
    
    echo -e "\n⚠️ Apply these optimizations? (y/n)"
    read apply_optimizations
    
    if [[ "$apply_optimizations" == "y" ]]; then
        echo "🔧 Applying optimizations..."
        
        # Apply CPU governor
        echo "⚙️ Setting CPU governor to performance mode..."
        sudo sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
        
        # Apply network optimizations
        echo "🌐 Applying network optimizations..."
        sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)
        
        # Create network optimization file
        cat > /tmp/network-optimizations.conf << EOF
# TCP Buffer Sizes
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=1048576
net.core.wmem_default=1048576
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# UDP buffer sizes for WebRTC
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

# TCP Congestion Control
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# Connection Performance
net.core.netdev_max_backlog=2500
net.ipv4.tcp_fastopen=3
net.core.somaxconn=8192

# Increase number of local ports available
net.ipv4.ip_local_port_range=1024 65535

# Increase the maximum socket receive buffer
net.core.optmem_max=25165824

# Further BBR optimizations
net.ipv4.tcp_notsent_lowat=16384

# Keeping connections alive - important for WebRTC
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6

# Disable slow start after idle
net.ipv4.tcp_slow_start_after_idle=0
EOF
        
        sudo cp /tmp/network-optimizations.conf /etc/sysctl.d/99-network-performance.conf
        sudo sysctl -p /etc/sysctl.d/99-network-performance.conf
        
        # Apply MiroTalk config optimizations
        extract_and_apply_config
        
        echo "✅ All optimizations applied!"
    else
        echo "🛑 Optimizations skipped."
    fi
    
    echo -e "\nPress Enter to continue..."
    read
}

# ====================================
# Main Menu Function
# ====================================

show_main_menu() {
    print_header
    echo "📂 App Path: $APP_PATH"
    echo "🔧 Service: $SERVICE_NAME"
    echo "🔌 Port: $PORT"
    echo ""
    
    # Check if the service is running
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo "🟢 Service is running"
    else
        echo "🔴 Service is stopped"
    fi
    
    echo -e "\nSelect an option:"
    PS3=$'\n'"Enter choice [1-7]: "
    options=(
        "🟢 Start service"
        "🔴 Stop service"
        "🔄 Restart service (with git pull)"
        "⚙️  Setup service"
        "📋 View logs"
        "🚀 Optimize for 4K"
        "🔙 Exit"
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "🟢 Start service")
                start_service
                break
                ;;
            "🔴 Stop service")
                stop_service
                break
                ;;
            "🔄 Restart service (with git pull)")
                restart_service
                break
                ;;
            "⚙️  Setup service")
                setup_service
                break
                ;;
            "📋 View logs")
                view_logs
                break
                ;;
            "🚀 Optimize for 4K")
                optimize_for_4k
                break
                ;;
            "🔙 Exit")
                echo -e "\n👋 Goodbye!"
                exit 0
                ;;
            *) 
                echo "❌ Invalid option"
                ;;
        esac
    done
}

# ====================================
# Main Loop
# ====================================

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Please do not run this script directly as root"
  exit 1
fi

while true; do
    show_main_menu
done
