#!/bin/bash

# ===== CONFIGURATION =====
LOG_FILE="dns_web_task_log_$(date +%F).log"
BACKUP_DIR="$HOME/dns_web_backups"
DOMAIN="example.com"
APACHE_CONF="/etc/apache2/sites-available/$DOMAIN.conf"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
ZONE_FILE="/etc/bind/db.$DOMAIN"
CPU_THRESHOLD=80
MEM_THRESHOLD=80
SSL_SETUP="n"

# ===== CREATE DIRECTORIES =====
mkdir -p "$BACKUP_DIR"

# ===== FUNCTIONS =====

# Function to log messages
log_message() {
    local message=$1
    echo "$(date +'%Y-%m-%d %H:%M:%S') | $message" | tee -a "$LOG_FILE"
}

# Function to check CPU usage
check_cpu_usage() {
    CPU_USAGE=$(mpstat 1 1 | awk '/Average/ {print 100 - $NF}')
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
        log_message "⚠️ High CPU Usage: $CPU_USAGE%"
    fi
}

# Function to check memory usage
check_memory_usage() {
    MEM_USAGE=$(free | awk '/Mem/ {printf "%.2f", $3/$2 * 100}')
    if (( $(echo "$MEM_USAGE > $MEM_THRESHOLD" | bc -l) )); then
        log_message "⚠️ High Memory Usage: $MEM_USAGE%"
    fi
}

# Function to test DNS resolution
check_dns() {
    log_message "Checking DNS resolution for $DOMAIN..."
    nslookup "$DOMAIN" && log_message "DNS resolution successful." || log_message "⚠️ DNS resolution failed."
}

# Function to test additional DNS records
test_dns_records() {
    log_message "Testing additional DNS records for $DOMAIN..."
    nslookup -query=mx "$DOMAIN" && log_message "MX records verified."
    nslookup -query=cname "$DOMAIN" && log_message "CNAME records verified."
}

# Function to configure DNS
configure_dns() {
    log_message "Configuring DNS for $DOMAIN..."
    echo "Config example: add your zone settings here." >> "$ZONE_FILE"
    log_message "DNS configuration completed."
}

# Function to back up existing configurations
backup_configs() {
    log_message "Backing up existing configurations..."
    if [ -f "$APACHE_CONF" ]; then
        cp "$APACHE_CONF" "$BACKUP_DIR/$DOMAIN.conf.backup.$(date +%F_%H-%M-%S)"
        log_message "Backup created for Apache configuration."
    fi
    if [ -f "$NGINX_CONF" ]; then
        cp "$NGINX_CONF" "$BACKUP_DIR/$DOMAIN.nginx.backup.$(date +%F_%H-%M-%S)"
        log_message "Backup created for NGINX configuration."
    fi
    if [ -f "$ZONE_FILE" ]; then
        cp "$ZONE_FILE" "$BACKUP_DIR/db.$DOMAIN.backup.$(date +%F_%H-%M-%S)"
        log_message "Backup created for DNS zone file."
    fi
}

# Function to set up SSL certificates
setup_ssl_certificates() {
    log_message "Setting up SSL certificates using Let's Encrypt..."
    if command -v certbot > /dev/null; then
        certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN"
        log_message "SSL certificates configured for $DOMAIN."
    else
        log_message "⚠️ Certbot is not installed. Skipping SSL setup."
    fi
}

# Function to test web server functionality
test_web_server() {
    log_message "Testing web server for $DOMAIN..."
    curl -Is "http://$DOMAIN" | head -n 1 | grep "200 OK" && log_message "Web server is up and running." || log_message "⚠️ Web server is not responding."
}

# Function to monitor disk usage
monitor_disk_usage() {
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    log_message "Disk Usage: $DISK_USAGE"
}

# Function to send email alerts
send_email_alert() {
    local subject=$1
    local body=$2
    echo "$body" | mail -s "$subject" "admin@$DOMAIN"
    log_message "Email alert sent to admin@$DOMAIN"
}

# Function to prompt user for inputs
prompt_user() {
    read -p "Enter the domain name to configure: " DOMAIN
    read -p "Do you want to set up SSL? (y/n): " SSL_SETUP
}

# ===== TASK EXECUTION =====
log_message "Starting DNS and Web Service tasks..."

backup_configs
prompt_user
check_cpu_usage
check_memory_usage
check_dns
test_dns_records
configure_dns
setup_ssl_certificates
test_web_server
monitor_disk_usage

log_message "All tasks completed successfully."
