#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

RES_COL=60
MOVE_TO_COL="echo -en \\033[${RES_COL}G"
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

echo_success() {
  $MOVE_TO_COL
  echo -n "["
  $SETCOLOR_SUCCESS
  echo -n " OK "
  $SETCOLOR_NORMAL
  echo -n "]"
  echo
  return 0
}

echo_failure() {
  $MOVE_TO_COL
  echo -n "["
  $SETCOLOR_FAILURE
  echo -n "FAILED"
  $SETCOLOR_NORMAL
  echo -n "]"
  echo
  return 1
}

handle_error() {
  echo -e "${RED}Error at line $1${NC}"
  exit 1
}

trap 'handle_error $LINENO' ERR

validate_ip() {
  local ip=$1
  local stat=1
  
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    IFS='.' read -r -a ip_segments <<< "$ip"
    [[ ${ip_segments[0]} -le 255 && ${ip_segments[1]} -le 255 && ${ip_segments[2]} -le 255 && ${ip_segments[3]} -le 255 ]]
    stat=$?
  fi
  
  return $stat
}

get_server_ip() {
  SERVER_IP=$(hostname -I | awk '{print $1}')
  
  if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(ip route get 1 | awk '{print $7; exit}')
  fi
  
  if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s ifconfig.me)
  fi
  
  echo -e "${YELLOW}Detected server IP: ${SERVER_IP}${NC}"
  echo -e "${CYAN}Is this IP correct? (y/n)${NC}"
  read -r confirm
  
  if [[ $confirm != "y" && $confirm != "Y" ]]; then
    while true; do
      echo -e "${CYAN}Please enter your server IP:${NC}"
      read -r SERVER_IP
      
      if validate_ip "$SERVER_IP"; then
        echo -e "${GREEN}Valid IP address.${NC}"
        break
      else
        echo -e "${RED}Invalid IP address. Please try again.${NC}"
      fi
    done
  fi
  
  echo -e "${GREEN}Server IP: ${SERVER_IP}${NC}"
}

get_internal_ping_ip() {
  while true; do
    echo -e "${CYAN}Please enter internal server IP for ping (default: 185.231.115.1):${NC}"
    read -r INTERNAL_IP
    
    if [ -z "$INTERNAL_IP" ]; then
      INTERNAL_IP="185.231.115.1"
      echo -e "${YELLOW}Using default IP: ${INTERNAL_IP}${NC}"
      break
    fi
    
    if validate_ip "$INTERNAL_IP"; then
      echo -e "${GREEN}Valid IP address.${NC}"
      break
    else
      echo -e "${RED}Invalid IP address. Please try again.${NC}"
    fi
  done
}

get_external_ping_ip() {
  while true; do
    echo -e "${CYAN}Please enter external server IP for ping (default: 8.8.8.8):${NC}"
    read -r EXTERNAL_IP
    
    if [ -z "$EXTERNAL_IP" ]; then
      EXTERNAL_IP="8.8.8.8"
      echo -e "${YELLOW}Using default IP: ${EXTERNAL_IP}${NC}"
      break
    fi
    
    if validate_ip "$EXTERNAL_IP"; then
      echo -e "${GREEN}Valid IP address.${NC}"
      break
    else
      echo -e "${RED}Invalid IP address. Please try again.${NC}"
    fi
  done
}

install_monitorix() {
  echo -e "${BLUE}Updating package list...${NC}"
  echo -n "Updating package list"
  apt-get update -qq > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
  
  echo -e "${BLUE}Installing Monitorix...${NC}"
  echo -n "Installing Monitorix"
  apt-get install -y monitorix -qq > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
  
  echo -e "${BLUE}Enabling Monitorix service...${NC}"
  echo -n "Enabling Monitorix service"
  systemctl enable monitorix > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
  
  echo -e "${BLUE}Opening port 8080...${NC}"
  echo -n "Opening port 8080"
  if command -v ufw > /dev/null 2>&1; then
    ufw allow 8080/tcp > /dev/null 2>&1
    echo_success
  elif command -v firewall-cmd > /dev/null 2>&1; then
    firewall-cmd --permanent --add-port=8080/tcp > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1
    echo_success
  else
    echo -e "${YELLOW}No firewall detected. Please ensure port 8080 is open.${NC}"
  fi
}

create_ping_script() {
  echo -e "${BLUE}Creating ping script...${NC}"
  echo -n "Creating ping script"
  
  cat > /usr/local/bin/ping_monitor.sh << EOF
#!/bin/bash

# External ping
ping -c 5 -nq ${EXTERNAL_IP} \\
  | tail -1 \\
  | awk '{ if(\$4=="") print "0"; else print \$4 }' \\
  | awk -F/ '{ print \$2 }' > /tmp/ping_ext.txt

# Internal ping
ping -c 5 -nq ${INTERNAL_IP} \\
  | tail -1 \\
  | awk '{ if(\$4=="") print "0"; else print \$4 }' \\
  | awk -F/ '{ print \$2 }' > /tmp/ping_int.txt
EOF
  
  chmod +x /usr/local/bin/ping_monitor.sh
  
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
}

create_cron_job() {
  echo -e "${BLUE}Creating cron job...${NC}"
  echo -n "Creating cron job"
  
  (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/ping_monitor.sh") | crontab -
  
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
}

configure_monitorix() {
  echo -e "${BLUE}Configuring Monitorix...${NC}"
  echo -n "Configuring Monitorix"
  
  sed -i 's/^enabled = n/enabled = y/g' /etc/monitorix/monitorix.conf
  
  if ! grep -q "gensens_file1" /etc/monitorix/monitorix.conf; then
    cat >> /etc/monitorix/monitorix.conf << EOF

# External ping
gensens_file1  = /tmp/ping_ext.txt
gensens_label1 = External Ping (${EXTERNAL_IP})
gensens_color1 = 00FF00

# Internal ping
gensens_file2  = /tmp/ping_int.txt
gensens_label2 = Internal Ping (${INTERNAL_IP})
gensens_color2 = FF0000
EOF
  fi
  
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
}

start_service() {
  echo -e "${BLUE}Starting Monitorix service...${NC}"
  echo -n "Starting Monitorix service"
  
  systemctl restart monitorix
  
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
  
  echo -e "${BLUE}Running ping script for the first time...${NC}"
  echo -n "Running ping script"
  
  /usr/local/bin/ping_monitor.sh
  
  if [ $? -eq 0 ]; then
    echo_success
  else
    echo_failure
    exit 1
  fi
}

show_service_status() {
  echo -e "${PURPLE}Monitorix service status:${NC}"
  systemctl status monitorix --no-pager
  
  echo -e "${GREEN}Monitorix service has been successfully installed and started.${NC}"
  echo -e "${GREEN}You can access the dashboard at:${NC}"
  echo -e "${CYAN}http://${SERVER_IP}:8080/monitorix/${NC}"
  echo -e "${YELLOW}Go to Generic Sensors in the left menu to see internal and external ping graphs.${NC}"
}

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}This script must be run as root.${NC}"
  exit 1
fi

echo -e "${CYAN}==================================================================${NC}"
echo -e "${YELLOW}           Automatic Monitorix Installation Script              ${NC}"
echo -e "${YELLOW}          For Internal and External Ping Monitoring             ${NC}"
echo -e "${CYAN}==================================================================${NC}"

get_server_ip
get_internal_ping_ip
get_external_ping_ip

install_monitorix
create_ping_script
create_cron_job
configure_monitorix
start_service

echo -e "${YELLOW}Showing service status in 10 seconds...${NC}"
sleep 10
show_service_status

exit 0
