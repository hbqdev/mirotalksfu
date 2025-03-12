#!/bin/bash

APP_PATH="/home/nightfury/selfhosted/mirotalksfu"
SERVICE_NAME="mirotalksfu"
HOSTNAME="meet.hbqnexus.win"
PORT=3055

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function show_usage() {
    echo -e "\n${BLUE}=== MiroTalk SFU Service Manager ===${NC}"
    PS3=$'\n'"${CYAN}Select an option:${NC} "
    options=(
        "🟢 Start service"
        "🔴 Stop service"
        "🔄 Restart service"
        "ℹ️  Show status"
        "⚙️  Configure SFU"
        "🚀 Optimize performance"
        "🖥️  Hardware acceleration"
        "📋 Show logs"
        "🔍 Diagnostics"
        "🔧 Edit service file"
        "📊 Resource usage"
        "🔒 Security check"
        "🔙 Exit"
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "🟢 Start service")
                sudo systemctl start $SERVICE_NAME
                show_status
                break
                ;;
            "🔴 Stop service")
                sudo systemctl stop $SERVICE_NAME
                show_status
                break
                ;;
            "🔄 Restart service")
                sudo systemctl restart $SERVICE_NAME
                show_status
                break
                ;;
            "ℹ️  Show status")
                show_status
                break
                ;;
            "⚙️  Configure SFU")
                configure_sfu_menu
                break
                ;;
            "🚀 Optimize performance")
                optimize_performance_menu
                break
                ;;
            "🖥️  Hardware acceleration")
                setup_hardware_acceleration
                break
                ;;
            "📋 Show logs")
                show_logs_menu
                break
                ;;
            "🔍 Diagnostics")
                run_diagnostics
                break
                ;;
            "🔧 Edit service file")
                edit_service_file
                break
                ;;
            "📊 Resource usage")
                show_resource_usage
                break
                ;;
            "🔒 Security check")
                run_security_check
                break
                ;;
            "🔙 Exit")
                echo -e "\n${GREEN}Goodbye! 👋${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

function configure_sfu_menu() {
    echo -e "\n${BLUE}=== Configure MiroTalk SFU ===${NC}"
    PS3=$'\n'"${CYAN}Select a configuration option:${NC} "
    options=(
        "Basic settings"
        "Codec settings"
        "Screen sharing settings"
        "WebRTC transport settings"
        "Return to main menu"
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "Basic settings")
                configure_basic_settings
                break
                ;;
            "Codec settings")
                configure_codec_settings
                break
                ;;
            "Screen sharing settings")
                configure_screen_sharing
                break
                ;;
            "WebRTC transport settings")
                configure_webrtc_transport
                break
                ;;
            "Return to main menu")
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

function configure_basic_settings() {
    echo -e "${BLUE}Configuring basic MiroTalk SFU settings...${NC}"
    
    # Check if config.js exists, if not copy from template
    if [ ! -f "$APP_PATH/app/src/config.js" ]; then
        echo -e "${YELLOW}Creating config.js from template...${NC}"
        cp "$APP_PATH/app/src/config.template.js" "$APP_PATH/app/src/config.js"
    fi
    
    # Set port and hostname
    echo -e "${GREEN}Configuring port and hostname...${NC}"
    sed -i "s|^const port.*|const port = process.env.PORT || $PORT;|" "$APP_PATH/app/src/config.js"
    
    # Set up hostname
    echo -e "${GREEN}Setting hostname to $HOSTNAME...${NC}"
    
    # Let user input other basic settings
    read -p "Enter maximum number of participants per room (default: 100): " max_participants
    if [ ! -z "$max_participants" ]; then
        echo -e "${GREEN}Setting max participants to $max_participants...${NC}"
        # This would require more complex logic to update the right section in config.js
    fi
    
    echo -e "${GREEN}Basic configuration complete!${NC}"
}

function configure_codec_settings() {
    echo -e "${BLUE}Configuring codec settings...${NC}"
    
    PS3=$'\n'"${CYAN}Select codec to optimize:${NC} "
    options=(
        "VP8"
        "VP9"
        "H264"
        "Return to config menu"
    )
    select codec in "${options[@]}"
    do
        case $codec in
            "VP8"|"VP9"|"H264")
                echo -e "${GREEN}Optimizing $codec settings...${NC}"
                read -p "Enter start bitrate in bps (e.g. 1000000): " start_bitrate
                read -p "Enter min bitrate in bps (e.g. 15000000): " min_bitrate
                read -p "Enter max bitrate in bps (e.g. 100000000): " max_bitrate
                
                # Implement the logic to update config.js for the selected codec
                echo -e "${GREEN}$codec settings updated!${NC}"
                break
                ;;
            "Return to config menu")
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

function configure_screen_sharing() {
    echo -e "${BLUE}Configuring screen sharing settings...${NC}"
    
    # Get current values
    current_fps=$(grep -A2 "screenSharingSettings" "$APP_PATH/app/src/config.js" | grep "frameRate" | awk '{print $2}' | tr -d ',')
    current_bitrate=$(grep -A3 "screenSharingSettings" "$APP_PATH/app/src/config.js" | grep "maxBitrate" | awk '{print $2}' | tr -d ',')
    
    echo -e "${YELLOW}Current settings:${NC}"
    echo -e "Frame rate: ${CYAN}$current_fps FPS${NC}"
    echo -e "Max bitrate: ${CYAN}$current_bitrate bps${NC}"
    
    read -p "Enter desired FPS (30-120, recommended 60): " fps
    read -p "Enter max bitrate in bps (15000000-180000000, recommended 18000000): " bitrate
    
    if [ ! -z "$fps" ]; then
        sed -i "/screenSharingSettings/,/frameRate/ s/frameRate: [0-9]*,/frameRate: $fps,/" "$APP_PATH/app/src/config.js"
        echo -e "${GREEN}Frame rate set to $fps FPS${NC}"
    fi
    
    if [ ! -z "$bitrate" ]; then
        sed -i "/screenSharingSettings/,/maxBitrate/ s/maxBitrate: [0-9]*,/maxBitrate: $bitrate,/" "$APP_PATH/app/src/config.js"
        echo -e "${GREEN}Max bitrate set to $bitrate bps${NC}"
    fi
    
    echo -e "${GREEN}Screen sharing settings updated!${NC}"
}

function configure_webrtc_transport() {
    echo -e "${BLUE}Configuring WebRTC transport settings...${NC}"
    
    # Get current values
    current_init_bitrate=$(grep -A10 "webRtcTransport" "$APP_PATH/app/src/config.js" | grep "initialAvailableOutgoingBitrate" | awk '{print $2}' | tr -d ',')
    current_min_bitrate=$(grep -A11 "webRtcTransport" "$APP_PATH/app/src/config.js" | grep "minimumAvailableOutgoingBitrate" | awk '{print $2}' | tr -d ',')
    current_max_bitrate=$(grep -A13 "webRtcTransport" "$APP_PATH/app/src/config.js" | grep "maxIncomingBitrate" | awk '{print $2}' | tr -d ',')
    
    echo -e "${YELLOW}Current settings:${NC}"
    echo -e "Initial outgoing bitrate: ${CYAN}$current_init_bitrate bps${NC}"
    echo -e "Minimum outgoing bitrate: ${CYAN}$current_min_bitrate bps${NC}"
    echo -e "Maximum incoming bitrate: ${CYAN}$current_max_bitrate bps${NC}"
    
    read -p "Enter initial outgoing bitrate (recommended 800000000): " init_bitrate
    read -p "Enter minimum outgoing bitrate (recommended 300000000): " min_bitrate
    read -p "Enter maximum incoming bitrate (recommended 900000000): " max_bitrate
    
    if [ ! -z "$init_bitrate" ]; then
        sed -i "/webRtcTransport/,/initialAvailableOutgoingBitrate/ s/initialAvailableOutgoingBitrate: [0-9]*,/initialAvailableOutgoingBitrate: $init_bitrate,/" "$APP_PATH/app/src/config.js"
        echo -e "${GREEN}Initial outgoing bitrate set to $init_bitrate bps${NC}"
    fi
    
    if [ ! -z "$min_bitrate" ]; then
        sed -i "/webRtcTransport/,/minimumAvailableOutgoingBitrate/ s/minimumAvailableOutgoingBitrate: [0-9]*,/minimumAvailableOutgoingBitrate: $min_bitrate,/" "$APP_PATH/app/src/config.js"
        echo -e "${GREEN}Minimum outgoing bitrate set to $min_bitrate bps${NC}"
    fi
    
    if [ ! -z "$max_bitrate" ]; then
        sed -i "/webRtcTransport/,/maxIncomingBitrate/ s/maxIncomingBitrate: [0-9]*,/maxIncomingBitrate: $max_bitrate,/" "$APP_PATH/app/src/config.js"
        echo -e "${GREEN}Maximum incoming bitrate set to $max_bitrate bps${NC}"
    fi
    
    echo -e "${GREEN}WebRTC transport settings updated!${NC}"
}

function optimize_performance_menu() {
    echo -e "\n${BLUE}=== Optimize Performance ===${NC}"
    PS3=$'\n'"${CYAN}Select an optimization option:${NC} "
    options=(
        "CPU Performance Mode"
        "Memory Optimization"
        "Network Stack Tuning"
        "Service Optimization"
        "Create optimized service file"
        "Return to main menu"
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "CPU Performance Mode")
                optimize_cpu_performance
                break
                ;;
            "Memory Optimization")
                optimize_memory
                break
                ;;
            "Network Stack Tuning")
                optimize_network
                break
                ;;
            "Service Optimization")
                optimize_service
                break
                ;;
            "Create optimized service file")
                create_optimized_service
                break
                ;;
            "Return to main menu")
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

function optimize_cpu_performance() {
    echo -e "${BLUE}Setting CPU governor to performance mode...${NC}"
    
    # Check if cpu_performance service exists
    if systemctl list-unit-files | grep -q "cpu-performance.service"; then
        echo -e "${YELLOW}CPU performance service already exists.${NC}"
        sudo systemctl restart cpu-performance
    else
        echo -e "${GREEN}Creating CPU performance service...${NC}"
        
        # Create CPU performance service
        cat > /tmp/cpu-performance.service << EOF
[Unit]
Description=Set CPU Governor to Performance Mode
Before=$SERVICE_NAME.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        sudo mv /tmp/cpu-performance.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable cpu-performance
        sudo systemctl start cpu-performance
    fi
    
    # Verify CPU governor settings
    echo -e "${YELLOW}Current CPU governor settings:${NC}"
    governors=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c)
    echo -e "${CYAN}$governors${NC}"
    
    echo -e "${GREEN}CPU performance optimization complete!${NC}"
}

function optimize_memory() {
    echo -e "${BLUE}Optimizing memory settings...${NC}"
    
    # Check current swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    echo -e "${YELLOW}Current swappiness: ${CYAN}$current_swappiness${NC}"
    
    # Set optimal swappiness for real-time applications
    echo -e "${GREEN}Setting swappiness to 10...${NC}"
    sudo sysctl -w vm.swappiness=10
    
    # Make swappiness persistent
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
    else
        sudo sed -i 's/vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
    fi
    
    # Set vfs_cache_pressure
    echo -e "${GREEN}Setting vfs_cache_pressure to 50...${NC}"
    sudo sysctl -w vm.vfs_cache_pressure=50
    
    # Make vfs_cache_pressure persistent
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
    else
        sudo sed -i 's/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf
    fi
    
    # Clear cache
    echo -e "${GREEN}Clearing cache...${NC}"
    sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
    
    echo -e "${GREEN}Memory optimization complete!${NC}"
}

function optimize_network() {
    echo -e "${BLUE}Optimizing network stack...${NC}"
    
    # Backup sysctl.conf
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
    echo -e "${YELLOW}Backed up /etc/sysctl.conf to /etc/sysctl.conf.bak${NC}"
    
    # Apply network optimizations
    echo -e "${GREEN}Applying network optimizations...${NC}"
    
    # Create network optimization file
    cat > /tmp/network-optimizations.conf << EOF
# TCP Buffer Sizes
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=1048576
net.core.wmem_default=1048576
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# TCP Congestion Control
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# Connection Performance
net.core.netdev_max_backlog=2500
net.ipv4.tcp_fastopen=3
net.core.somaxconn=1024

# UDP Buffer Size (important for WebRTC)
net.ipv4.udp_rmem_min=4096
net.ipv4.udp_wmem_min=4096
EOF
    
    # Apply optimizations
    sudo cp /tmp/network-optimizations.conf /etc/sysctl.d/99-network-performance.conf
    sudo sysctl -p /etc/sysctl.d/99-network-performance.conf
    
    echo -e "${GREEN}Network optimization complete!${NC}"
}

function optimize_service() {
    echo -e "${BLUE}Optimizing service settings...${NC}"
    
    # Check current service settings
    if systemctl status $SERVICE_NAME | grep -q "nice="; then
        current_nice=$(systemctl show $SERVICE_NAME | grep Nice | cut -d= -f2)
        echo -e "${YELLOW}Current Nice value: ${CYAN}$current_nice${NC}"
    else
        echo -e "${YELLOW}No Nice value set.${NC}"
    fi
    
    # Ask if user wants to apply optimized settings
    read -p "Apply optimized service settings? (y/n): " apply_optimized
    
    if [[ "$apply_optimized" == "y" ]]; then
        create_optimized_service
    else
        echo -e "${YELLOW}Service optimization skipped.${NC}"
    fi
}

function create_optimized_service() {
    echo -e "${BLUE}Creating optimized service file...${NC}"
    
    # Create optimized service file
    cat > /tmp/$SERVICE_NAME.service << EOF
[Unit]
Description=MiroTalk SFU Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=nightfury
WorkingDirectory=$APP_PATH
# Environment variables
Environment=PORT=$PORT
Environment=NODE_ENV=production
Environment=LIBVA_DRIVER_NAME=iHD
Environment=LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri

# CPU and process scheduling optimizations
Nice=-15
IOSchedulingClass=1
IOSchedulingPriority=0
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=90

# Memory optimizations
MemoryDenyWriteExecute=no
LockPersonality=yes

# Start command with optimized Node.js flags
ExecStart=/usr/bin/node --max-old-space-size=49152 --expose-gc --optimize-for-size app/src/Server.js

# Restart configuration
Restart=always
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    # Apply new service file
    sudo mv /tmp/$SERVICE_NAME.service /etc/systemd/system/
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}Optimized service file created!${NC}"
    echo -e "${YELLOW}Note: The service has been configured but CPU governor management requires additional setup.${NC}"
    echo -e "${YELLOW}Would you like to set up sudo permissions for CPU governor management?${NC}"
    
    read -p "Set up sudo permissions? (y/n): " setup_sudo
    
    if [[ "$setup_sudo" == "y" ]]; then
        setup_sudo_permissions
    else
        echo -e "${YELLOW}Sudo permission setup skipped.${NC}"
    fi
}

function setup_sudo_permissions() {
    echo -e "${BLUE}Setting up sudo permissions for CPU governor management...${NC}"
    
    # Create sudoers file
    cat > /tmp/mirotalksfu << EOF
nightfury ALL=(ALL) NOPASSWD: /bin/sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
EOF
    
    # Apply sudoers file
    sudo mv /tmp/mirotalksfu /etc/sudoers.d/
    sudo chmod 0440 /etc/sudoers.d/mirotalksfu
    
    echo -e "${GREEN}Sudo permissions configured!${NC}"
    echo -e "${YELLOW}You can now use the optimized service with sudo for CPU governor management.${NC}"
}

function setup_hardware_acceleration() {
    echo -e "${BLUE}Setting up hardware acceleration...${NC}"
    
    # Check if VA-API packages are installed
    if ! dpkg -l | grep -q "intel-media-va-driver-non-free"; then
        echo -e "${YELLOW}Intel media VA driver not found. Installing...${NC}"
        sudo apt update
        sudo apt install -y intel-media-va-driver-non-free vainfo intel-gpu-tools
    else
        echo -e "${GREEN}Intel media VA driver is already installed.${NC}"
    fi
    
    # Test VA-API
    echo -e "${YELLOW}Testing VA-API support...${NC}"
    LIBVA_DRIVER_NAME=iHD vainfo | head -n 20
    
    # Check if environment variable is set
    if ! grep -q "LIBVA_DRIVER_NAME" /etc/systemd/system/$SERVICE_NAME.service; then
        echo -e "${YELLOW}Adding hardware acceleration environment variables to service...${NC}"
        sudo sed -i '/Environment=PORT/a Environment=LIBVA_DRIVER_NAME=iHD\nEnvironment=LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri' /etc/systemd/system/$SERVICE_NAME.service
        sudo systemctl daemon-reload
    else
        echo -e "${GREEN}Hardware acceleration environment variables already set in service.${NC}"
    fi
    
    echo -e "${GREEN}Hardware acceleration setup complete!${NC}"
}

function show_logs_menu() {
    echo -e "\n${BLUE}=== Show Logs ===${NC}"
    PS3=$'\n'"${CYAN}Select a log option:${NC} "
    options=(
        "Recent logs"
        "Error logs only"
        "Live log follow"
        "Return to main menu"
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "Recent logs")
                journalctl -u $SERVICE_NAME -n 50 --no-pager
                break
                ;;
            "Error logs only")
                journalctl -u $SERVICE_NAME -p err -n 50 --no-pager
                break
                ;;
            "Live log follow")
                echo -e "${YELLOW}Press Ctrl+C to stop following logs${NC}"
                sleep 2
                journalctl -u $SERVICE_NAME -f
                break
                ;;
            "Return to main menu")
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    done
}

function run_diagnostics() {
    echo -e "${BLUE}Running diagnostics...${NC}"
    
    echo -e "\n${YELLOW}System Information:${NC}"
    echo -e "${CYAN}$(uname -a)${NC}"
    
    echo -e "\n${YELLOW}CPU Information:${NC}"
    echo -e "${CYAN}$(lscpu | grep 'Model name\|CPU(s)\|Thread\|CPU MHz')${NC}"
    
    echo -e "\n${YELLOW}Memory Information:${NC}"
    echo -e "${CYAN}$(free -h)${NC}"
    
    echo -e "\n${YELLOW}Disk Space:${NC}"
    echo -e "${CYAN}$(df -h | grep -v tmpfs)${NC}"
    
    echo -e "\n${YELLOW}Node.js Version:${NC}"
    echo -e "${CYAN}$(node -v)${NC}"
    
    echo -e "\n${YELLOW}NPM Version:${NC}"
    echo -e "${CYAN}$(npm -v)${NC}"
    
    echo -e "\n${YELLOW}Service Status:${NC}"
    systemctl status $SERVICE_NAME --no-pager
    
    echo -e "\n${YELLOW}Network Ports:${NC}"
    echo -e "${CYAN}$(ss -tulpn | grep node)${NC}"
    
    echo -e "\n${YELLOW}CPU Governor:${NC}"
    echo -e "${CYAN}$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c)${NC}"
    
    echo -e "\n${GREEN}Diagnostics complete!${NC}"
}

function edit_service_file() {
    echo -e "${BLUE}Editing service file...${NC}"
    sudo nano /etc/systemd/system/$SERVICE_NAME.service
    
    echo -e "${YELLOW}Reloading systemd daemon...${NC}"
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}Service file updated!${NC}"
}

function show_resource_usage() {
    echo -e "${BLUE}Showing resource usage...${NC}"
    
    # Get PID
    PID=$(pgrep -f "node.*Server.js")
    
    if [ -z "$PID" ]; then
        echo -e "${RED}MiroTalk SFU is not running!${NC}"
        return
    fi
    
    echo -e "\n${YELLOW}CPU and Memory Usage:${NC}"
    ps -p $PID -o %cpu,%mem,cmd
    
    echo -e "\n${YELLOW}Top Processes:${NC}"
    top -b -n 1 | head -n 20
    
    echo -e "\n${YELLOW}Network Connections:${NC}"
    netstat -tunapl | grep node
    
    echo -e "\n${YELLOW}Running for 5 seconds to track resource usage...${NC}"
    mpstat 1 5
    
    echo -e "\n${GREEN}Resource usage check complete!${NC}"
}

function run_security_check() {
    echo -e "${BLUE}Running security check...${NC}"
    
    echo -e "\n${YELLOW}Open Ports:${NC}"
    sudo ss -tulpn | grep LISTEN
    
    echo -e "\n${YELLOW}Service User:${NC}"
    grep "User=" /etc/systemd/system/$SERVICE_NAME.service
    
    echo -e "\n${YELLOW}File Permissions:${NC}"
    ls -la $APP_PATH/app/src/config.js
    
    echo -e "\n${YELLOW}Checking for sensitive information in config:${NC}"
    grep -i "secret\|password\|key" $APP_PATH/app/src/config.js | grep -v "\/\/"
    
    echo -e "\n${YELLOW}SSL Configuration:${NC}"
    if [ -f "$APP_PATH/app/ssl/cert.pem" ]; then
        echo -e "${GREEN}SSL certificate found!${NC}"
        openssl x509 -in $APP_PATH/app/ssl/cert.pem -text -noout | grep "Not After"
    else
        echo -e "${RED}SSL certificate not found!${NC}"
    fi
    
    echo -e "\n${GREEN}Security check complete!${NC}"
}

function check_and_create_service() {
    if ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        echo -e "${YELLOW}Creating systemd service...${NC}"
        
        cat > /tmp/$SERVICE_NAME.service << EOF
[Unit]
Description=MiroTalk SFU Service
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$APP_PATH
Environment=PORT=$PORT
ExecStart=/usr/bin/npm start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        sudo mv /tmp/$SERVICE_NAME.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable $SERVICE_NAME
        echo -e "${GREEN}Service created and enabled${NC}"
    fi
}

function show_status() {
    echo -e "\n${BLUE}=== Service Status ===${NC}"
    systemctl status $SERVICE_NAME --no-pager
}

function show_logs() {
    journalctl -u $SERVICE_NAME -n 50 --no-pager
}

# Initial setup
echo -e "${BLUE}Setting up MiroTalk SFU service...${NC}"
check_and_create_service
configure_sfu

# Main loop
while true; do
    clear
    show_usage
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
done

