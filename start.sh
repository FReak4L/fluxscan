#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}==================================================================${NC}"
echo -e "${YELLOW}                     FluxScan Menu                              ${NC}"
echo -e "${YELLOW}                 By @NotePadVPN                                 ${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""
echo -e "${GREEN}1.${NC} Install FluxScan"
echo -e "${RED}2.${NC} Uninstall FluxScan"
echo -e "${YELLOW}3.${NC} Exit"
echo ""
echo -e "${CYAN}==================================================================${NC}"
echo -e "${BLUE}Follow us on Telegram: @NotePadVPN${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

read -p "Please select an option [1-3]: " choice

case $choice in
    1)
        echo -e "${GREEN}Installing FluxScan...${NC}"
        if [ -f "./main.sh" ]; then
            bash ./main.sh
        else
            echo -e "${RED}Error: main.sh not found in current directory${NC}"
            echo -e "${YELLOW}Downloading main.sh from GitHub...${NC}"
            curl -s -O https://raw.githubusercontent.com/FReak4L/fluxscan/main/main.sh
            if [ $? -eq 0 ]; then
                chmod +x main.sh
                bash ./main.sh
            else
                echo -e "${RED}Failed to download main.sh. Please check your internet connection.${NC}"
                exit 1
            fi
        fi
        ;;
    2)
        echo -e "${RED}Uninstalling FluxScan...${NC}"
        # Add uninstall commands here
        echo -e "${YELLOW}Removing cron jobs...${NC}"
        (crontab -l | grep -v "ping_monitor.sh") | crontab -
        
        echo -e "${YELLOW}Stopping Monitorix service...${NC}"
        systemctl stop monitorix
        
        echo -e "${YELLOW}Disabling Monitorix service...${NC}"
        systemctl disable monitorix
        
        echo -e "${YELLOW}Removing installed packages...${NC}"
        apt-get remove -y monitorix
        
        echo -e "${YELLOW}Removing script files...${NC}"
        rm -f /usr/local/bin/ping_monitor.sh
        rm -f /tmp/ping_ext.txt
        rm -f /tmp/ping_int.txt
        
        echo -e "${GREEN}FluxScan has been uninstalled successfully!${NC}"
        ;;
    3)
        echo -e "${BLUE}Exiting...${NC}"
        echo -e "${YELLOW}Thank you for using FluxScan by @NotePadVPN${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option. Please try again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Operation completed!${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo -e "${YELLOW}           Thank you for using FluxScan                         ${NC}"
echo -e "${YELLOW}           Follow @NotePadVPN for more tools                    ${NC}"
echo -e "${CYAN}==================================================================${NC}"

exit 0
