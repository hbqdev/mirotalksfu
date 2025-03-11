#!/bin/bash
APP_PATH="/home/nightfury/selfhosted/mirotalksfu"
SERVICE_NAME="mirotalksfu"
HOSTNAME="meet.hbqnexus.win"
PORT=3055

function show_usage() {
    echo -e "\n=== MiroTalk SFU Service Manager ==="
    PS3=$'\nSelect an option: '
    options=(
        "🟢 Start service"
        "🔴 Stop service"
        "🔄 Restart service"
        "ℹ️  Show status"
        "⚙️  Configure SFU"
        "📋 Show logs"
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
                configure_sfu
                break
                ;;
            "📋 Show logs")
                show_logs
                break
                ;;
            "🔙 Exit")
                echo -e "\nGoodbye! 👋"
                exit 0
                ;;
            *) 
                echo "Invalid option"
                ;;
        esac
    done
}

function configure_sfu() {
    echo "Configuring MiroTalk SFU..."
    
    # Check if config.js exists, if not copy from template
    if [ ! -f "$APP_PATH/app/src/config.js" ]; then
        echo "Creating config.js from template..."
        cp "$APP_PATH/app/src/config.template.js" "$APP_PATH/app/src/config.js"
    fi
    
    # Set optimal streaming settings in config.js
    echo "Configuring for optimal streaming..."
    sed -i "s|^const port.*|const port = process.env.PORT || $PORT;|" "$APP_PATH/app/src/config.js"
    sed -i "s|announcedIp:.*|announcedIp: null,|" "$APP_PATH/app/src/config.js"
    
    # Customize hostname and other settings
    echo "Setting hostname to $HOSTNAME..."
    echo "Configuration complete!"
}

function check_and_create_service() {
    if ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        echo "Creating systemd service..."
        
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
        echo "Service created and enabled"
    fi
}

function show_status() {
    echo -e "\n=== Service Status ==="
    systemctl status $SERVICE_NAME --no-pager
}

function show_logs() {
    journalctl -u $SERVICE_NAME -n 50 --no-pager
}

# Initial setup
echo "Setting up MiroTalk SFU service..."
check_and_create_service
configure_sfu

# Main loop
while true; do
    clear
    show_usage
    echo -e "\nPress Enter to continue..."
    read
done

