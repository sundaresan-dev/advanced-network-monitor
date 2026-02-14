#!/bin/bash

# ============================================================================
# SMART SRE NETWORK MONITOR - Enterprise Edition
# ============================================================================

# Color codes for better readability - Fixed for help section
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'  # Changed from \033[1;33m to standard yellow
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
ORANGE='\033[0;33m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'
NC='\033[0m' # No Color

# Unicode symbols for better UI
CHECK_MARK="✓"
CROSS_MARK="✗"
WARNING_MARK="⚠"
INFO_MARK="ℹ"
ARROW_MARK="→"
BULLET_MARK="•"
BOX_DRAWING_HORIZONTAL="─"
BOX_DRAWING_VERTICAL="│"
BOX_DRAWING_CORNER_TL="┌"
BOX_DRAWING_CORNER_TR="┐"
BOX_DRAWING_CORNER_BL="└"
BOX_DRAWING_CORNER_BR="┘"
BOX_DRAWING_TEE_DOWN="┬"
BOX_DRAWING_TEE_UP="┴"
BOX_DRAWING_TEE_LEFT="├"
BOX_DRAWING_TEE_RIGHT="┤"

# Default configuration
DEFAULT_PORTS=(22 80 443 3306 5432 27017 6379 8080 8443 9200 5601 9090 3000)
DEFAULT_INTERVAL=30
LOG_FILE=""
CONTINUOUS_MODE=false
INTERVAL=$DEFAULT_INTERVAL
NO_TRACEROUTE=false
JSON_OUTPUT=false
VERBOSE=false
ALERT_THRESHOLD=80
PERFORMANCE_LOG="performance-$(date +%Y%m%d).csv"

# Threshold defaults (can be overridden by env vars)
LATENCY_WARN=${LATENCY_WARN:-150}      # ms
LATENCY_CRIT=${LATENCY_CRIT:-300}      # ms
PACKET_LOSS_WARN=${PACKET_LOSS_WARN:-2} # %
PACKET_LOSS_CRIT=${PACKET_LOSS_CRIT:-5} # %
DNS_TIME_WARN=${DNS_TIME_WARN:-100}     # ms
DNS_TIME_CRIT=${DNS_TIME_CRIT:-200}     # ms
SSL_EXPIRY_WARN=${SSL_EXPIRY_WARN:-30}  # days
SSL_EXPIRY_CRIT=${SSL_EXPIRY_CRIT:-7}   # days
RESPONSE_TIME_WARN=${RESPONSE_TIME_WARN:-500}  # ms
RESPONSE_TIME_CRIT=${RESPONSE_TIME_CRIT:-1000} # ms

# Initialize variables
TARGET=""
IP=""
ISSUE=""
SOLUTION=""
declare -a WARNINGS=()
declare -a CRITICAL=()
declare -a METRICS=()
declare -a HISTORY=()
declare -a OPEN_PORTS=()
HEALTH_SCORE=100
CHECK_COUNT=0
FAILURE_COUNT=0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to draw a horizontal line
draw_line() {
    local width=${1:-80}
    printf "${CYAN}${BOX_DRAWING_HORIZONTAL}%.0s${NC}" $(seq 1 $width)
    echo
}

# Function to draw a boxed section header
draw_section_header() {
    local title=$1
    local color=${2:-$BLUE}
    echo
    echo -e "${color}${BOX_DRAWING_CORNER_TL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL} ${BOLD}${title}${NC} ${color}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_CORNER_TR}${NC}"
}

# Function to draw a status box
draw_status_box() {
    local status=$1
    local message=$2
    local details=$3
    
    case $status in
        OK)
            echo -e "  ${GREEN}${BOX_DRAWING_VERTICAL} ${CHECK_MARK}${NC} ${GREEN}${message}${NC}"
            [ -n "$details" ] && echo -e "  ${GREEN}${BOX_DRAWING_VERTICAL}   ${DIM}${details}${NC}"
            ;;
        WARN)
            echo -e "  ${YELLOW}${BOX_DRAWING_VERTICAL} ${WARNING_MARK}${NC} ${YELLOW}${message}${NC}"
            [ -n "$details" ] && echo -e "  ${YELLOW}${BOX_DRAWING_VERTICAL}   ${DIM}${details}${NC}"
            ;;
        FAIL)
            echo -e "  ${RED}${BOX_DRAWING_VERTICAL} ${CROSS_MARK}${NC} ${RED}${message}${NC}"
            [ -n "$details" ] && echo -e "  ${RED}${BOX_DRAWING_VERTICAL}   ${DIM}${details}${NC}"
            ;;
        INFO)
            echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL} ${INFO_MARK}${NC} ${BLUE}${message}${NC}"
            [ -n "$details" ] && echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   ${DIM}${details}${NC}"
            ;;
    esac
}

# Improved help function with boxed UI
show_help() {
    clear
    echo -e "${CYAN}${BOX_DRAWING_CORNER_TL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_CORNER_TR}${NC}"
    echo -e "${CYAN}${BOX_DRAWING_VERTICAL}${NC} ${BOLD}${WHITE}SMART SRE NETWORK MONITOR - HELP${NC}${CYAN}${BOX_DRAWING_VERTICAL}${NC}"
    echo -e "${CYAN}${BOX_DRAWING_TEE_LEFT}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_TEE_RIGHT}${NC}"
    
    cat << EOF

${BOLD}${WHITE}USAGE:${NC}
  ${CYAN}$0 [OPTIONS]${NC}

${BOLD}${WHITE}BASIC OPTIONS:${NC}
  ${GREEN}-t, --target DOMAIN/IP${NC}    ${DIM}Target domain or IP address (required)${NC}
  ${GREEN}-p, --ports "LIST"${NC}        ${DIM}Custom ports to check (space-separated in quotes)${NC}
  ${GREEN}-h, --help${NC}                 ${DIM}Show this help message${NC}

${BOLD}${WHITE}OUTPUT OPTIONS:${NC}
  ${GREEN}-j, --json${NC}                 ${DIM}Output in JSON format${NC}
  ${GREEN}-v, --verbose${NC}              ${DIM}Verbose output with detailed information${NC}
  ${GREEN}-l, --log FILE${NC}             ${DIM}Log output to specified file${NC}

${BOLD}${WHITE}CONTINUOUS MONITORING:${NC}
  ${GREEN}-c, --continuous${NC}           ${DIM}Run in continuous monitoring mode${NC}
  ${GREEN}-i, --interval SECONDS${NC}     ${DIM}Check interval in seconds (default: 30)${NC}

${BOLD}${WHITE}FEATURE TOGGLES:${NC}
  ${GREEN}--no-traceroute${NC}            ${DIM}Skip traceroute on failure${NC}
  ${GREEN}--no-security${NC}              ${DIM}Skip security checks${NC}
  ${GREEN}--no-dependency${NC}            ${DIM}Skip dependency analysis${NC}

${BOLD}${WHITE}THRESHOLD TUNING:${NC}
  ${YELLOW}Latency:${NC}                   ${DIM}LATENCY_WARN=${LATENCY_WARN}ms, LATENCY_CRIT=${LATENCY_CRIT}ms${NC}
  ${YELLOW}Packet Loss:${NC}               ${DIM}PACKET_LOSS_WARN=${PACKET_LOSS_WARN}%, PACKET_LOSS_CRIT=${PACKET_LOSS_CRIT}%${NC}
  ${YELLOW}DNS Time:${NC}                  ${DIM}DNS_TIME_WARN=${DNS_TIME_WARN}ms, DNS_TIME_CRIT=${DNS_TIME_CRIT}ms${NC}
  ${YELLOW}SSL Expiry:${NC}                ${DIM}SSL_EXPIRY_WARN=${SSL_EXPIRY_WARN}days, SSL_EXPIRY_CRIT=${SSL_EXPIRY_CRIT}days${NC}
  ${YELLOW}Response Time:${NC}             ${DIM}RESPONSE_TIME_WARN=${RESPONSE_TIME_WARN}ms, RESPONSE_TIME_CRIT=${RESPONSE_TIME_CRIT}ms${NC}

${BOLD}${WHITE}EXAMPLES:${NC}
  ${CYAN}Basic run:${NC}
    ${BOLD}$0 -t google.com${NC}
  
  ${CYAN}Continuous monitoring every 30s with logging:${NC}
    ${BOLD}$0 -t google.com -c -i 30 -l /var/log/sre.log${NC}
  
  ${CYAN}Custom ports, skip traceroute:${NC}
    ${BOLD}$0 -t myapp.com -p "22 80 443 8080 3306" --no-traceroute${NC}
  
  ${CYAN}Tune thresholds via env vars:${NC}
    ${BOLD}LATENCY_WARN=50 LATENCY_CRIT=200 PACKET_LOSS_WARN=5 $0 -t myserver.com${NC}
  
  ${CYAN}JSON output for automation:${NC}
    ${BOLD}$0 -t api.example.com -j${NC}
  
  ${CYAN}Verbose mode with security checks:${NC}
    ${BOLD}$0 -t example.com -v --no-security${NC}

EOF

    echo -e "${CYAN}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_CORNER_BR}${NC}"
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target) TARGET="$2"; shift 2 ;;
            -p|--ports) IFS=' ' read -ra PORTS <<< "$2"; shift 2 ;;
            -l|--log) LOG_FILE="$2"; shift 2 ;;
            -i|--interval) INTERVAL="$2"; shift 2 ;;
            -c|--continuous) CONTINUOUS_MODE=true; shift ;;
            -j|--json) JSON_OUTPUT=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            --no-traceroute) NO_TRACEROUTE=true; shift ;;
            --no-security) NO_SECURITY=true; shift ;;
            --no-dependency) NO_DEPENDENCY=true; shift ;;
            -h|--help) show_help ;;
            *) echo "Unknown option: $1"; show_help ;;
        esac
    done

    # Validate required arguments
    if [ -z "$TARGET" ]; then
        echo -e "${YELLOW}${INFO_MARK} No target specified.${NC}"
        read -p "$(echo -e "${CYAN}Enter Domain or IP: ${NC}")" TARGET
    fi

    # Set default ports if not specified
    if [ ${#PORTS[@]} -eq 0 ]; then
        PORTS=("${DEFAULT_PORTS[@]}")
    fi

    # Setup logging
    if [ -n "$LOG_FILE" ]; then
        exec > >(tee -a "$LOG_FILE") 2>&1
        echo -e "${BLUE}${INFO_MARK} Logging to: $LOG_FILE${NC}"
    fi
}

# Function to check if input is IP (IPv4 and IPv6)
is_ip() {
    [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
    [[ $1 =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]
}

# Function to log metrics
log_metric() {
    local name=$1
    local value=$2
    local unit=$3
    local severity=${4:-"info"}
    METRICS+=("$name: $value $unit")
    
    # Log to CSV for trending
    echo "$(date +%Y-%m-%d,%H:%M:%S),$TARGET,$name,$value,$unit" >> "$PERFORMANCE_LOG"
    
    # Check thresholds and add warnings/criticals
    case $name in
        "latency")
            check_threshold "$value" "$LATENCY_WARN" "$LATENCY_CRIT" "Latency" "$unit"
            ;;
        "packet_loss")
            check_threshold "$value" "$PACKET_LOSS_WARN" "$PACKET_LOSS_CRIT" "Packet Loss" "$unit"
            ;;
        "dns_time")
            check_threshold "$value" "$DNS_TIME_WARN" "$DNS_TIME_CRIT" "DNS Time" "$unit"
            ;;
        "response_time")
            check_threshold "$value" "$RESPONSE_TIME_WARN" "$RESPONSE_TIME_CRIT" "Response Time" "$unit"
            ;;
        "ssl_days_left")
            if [ "$value" -lt "$SSL_EXPIRY_CRIT" ]; then
                CRITICAL+=("SSL certificate expires in $value days")
            elif [ "$value" -lt "$SSL_EXPIRY_WARN" ]; then
                WARNINGS+=("SSL certificate expires in $value days")
            fi
            ;;
    esac
}

# Function to check thresholds
check_threshold() {
    local value=$1
    local warn=$2
    local crit=$3
    local name=$4
    local unit=$5
    
    if (( $(echo "$value > $crit" | bc -l 2>/dev/null || echo 0) )); then
        CRITICAL+=("$name critical: $value $unit (threshold: $crit $unit)")
        HEALTH_SCORE=$((HEALTH_SCORE - 20))
    elif (( $(echo "$value > $warn" | bc -l 2>/dev/null || echo 0) )); then
        WARNINGS+=("$name warning: $value $unit (threshold: $warn $unit)")
        HEALTH_SCORE=$((HEALTH_SCORE - 10))
    fi
}

# Function to print colored status (updated to use new UI)
print_status() {
    local status=$1
    local message=$2
    local details=$3
    
    draw_status_box "$status" "$message" "$details"
}

# Function to calculate health score
calculate_health_score() {
    HEALTH_SCORE=100
    HEALTH_SCORE=$((HEALTH_SCORE - (${#WARNINGS[@]} * 5)))
    HEALTH_SCORE=$((HEALTH_SCORE - (${#CRITICAL[@]} * 20)))
    [ $HEALTH_SCORE -lt 0 ] && HEALTH_SCORE=0
}

# ============================================================================
# MONITORING FUNCTIONS
# ============================================================================

# DNS Check (updated with new UI)
check_dns() {
    draw_section_header "1. DNS CHECK" "$BLUE"
    echo -e "${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
    
    if is_ip $TARGET; then
        IP=$TARGET
        print_status "INFO" "Input detected as IP address" "No DNS resolution needed"
    else
        # Try multiple DNS servers
        local dns_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222")
        local resolved=false
        
        for DNS in "${dns_servers[@]}"; do
            local start_time=$(date +%s%N)
            IP=$(dig +short @$DNS $TARGET | head -n 1)
            local end_time=$(date +%s%N)
            local dns_time=$(( ($end_time - $start_time) / 1000000 ))
            
            if [ -n "$IP" ]; then
                print_status "OK" "DNS Resolved via $DNS" "$TARGET → $IP (${dns_time}ms)"
                log_metric "dns_time" "$dns_time" "ms"
                resolved=true
                break
            fi
        done
        
        if [ "$resolved" = false ]; then
            ISSUE="DNS Resolution Failure"
            SOLUTION="Check DNS server, verify domain spelling, restart DNS service or check /etc/resolv.conf."
            print_status "FAIL" "$ISSUE" "$SOLUTION"
            echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
            return 1
        fi
        
        # DNSSEC check
        if dig +dnssec $TARGET | grep -q "ad;"; then
            print_status "OK" "DNSSEC validated" "Security extension verified"
        fi
        
        # Get all IPs (for load balancers)
        local all_ips=$(dig +short $TARGET)
        if [ $(echo "$all_ips" | wc -l) -gt 1 ]; then
            print_status "INFO" "Multiple IPs found" "Load balancer detected"
            echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   ${DIM}IPs: $(echo $all_ips | tr '\n' ' ')${NC}"
        fi
        
        # Reverse DNS lookup
        local reverse_dns=$(dig +short -x $IP)
        if [ -n "$reverse_dns" ]; then
            print_status "OK" "Reverse DNS" "$reverse_dns"
        fi
    fi
    echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
    return 0
}

# Network Layer Checks (updated with new UI)
check_network() {
    draw_section_header "2. NETWORK LAYER CHECKS" "$BLUE"
    echo -e "${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
    
    if ping -c 4 $IP &>/dev/null; then
        local ping_output=$(ping -c 4 $IP 2>/dev/null)
        
        # Extract metrics
        local latency=$(echo "$ping_output" | grep 'rtt' | awk -F '/' '{print $5}')
        local packet_loss=$(echo "$ping_output" | grep -oP '\d+(?=% packet loss)')
        local jitter=$(echo "$ping_output" | grep 'rtt' | awk -F '/' '{print $6}')
        
        print_status "OK" "Host Reachable" "ICMP packets received"
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   ${DIM}Latency: ${latency}ms (avg) | Jitter: ${jitter}ms | Packet Loss: ${packet_loss}%${NC}"
        
        # Log metrics
        log_metric "latency" "$latency" "ms"
        log_metric "jitter" "$jitter" "ms"
        log_metric "packet_loss" "$packet_loss" "%"
        
        # Connection stability test
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
        print_status "INFO" "Connection stability" "Testing with 10 pings..."
        local stability_output=$(ping -c 10 $IP 2>/dev/null)
        if [ $? -eq 0 ]; then
            local loss=$(echo "$stability_output" | grep -oP '\d+(?=% packet loss)')
            if [ "$loss" -lt 2 ]; then
                print_status "OK" "Stable connection" "${loss}% packet loss"
            elif [ "$loss" -lt 5 ]; then
                print_status "WARN" "Moderate packet loss" "${loss}% loss detected"
            else
                print_status "FAIL" "Unstable connection" "${loss}% packet loss"
            fi
        fi
    else
        ISSUE="Network Connectivity Issue"
        SOLUTION="Server unreachable. Check firewall, routing, security groups or server status."
        print_status "FAIL" "$ISSUE" "$SOLUTION"
        
        # Traceroute on failure (unless disabled)
        if [ "$NO_TRACEROUTE" = false ]; then
            echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
            print_status "INFO" "Running traceroute" "Path analysis:"
            echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   $(traceroute -m 15 $IP 2>/dev/null | head -5 | tr '\n' ' ' | sed 's/  / /g')${NC}"
        fi
        echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
        return 1
    fi
    
    # MTR check if available and verbose mode
    if command -v mtr &>/dev/null && [ "$VERBOSE" = true ]; then
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
        print_status "INFO" "Quick MTR report" "Top 5 hops:"
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   $(mtr -r -c 5 $IP | tail -5 | tr '\n' ' ' | sed 's/  / /g')${NC}"
    fi
    echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
    return 0
}

# Port Scanning (updated with new UI)
check_ports() {
    draw_section_header "3. PORT SCANNING & SERVICE DETECTION" "$BLUE"
    echo -e "${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
    
    OPEN_PORTS=()
    local total_ports=${#PORTS[@]}
    local current=0
    local open_count=0
    
    echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL} ${DIM}Scanning ports:${NC}"
    echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   ${DIM}[", with progress bar
    
    for PORT in "${PORTS[@]}"; do
        current=$((current + 1))
        
        # Show progress
        local percent=$((current * 100 / total_ports))
        local bar_length=30
        local filled=$((percent * bar_length / 100))
        local empty=$((bar_length - filled))
        printf "\r  ${BLUE}${BOX_DRAWING_VERTICAL}   [${GREEN}"
        printf "%${filled}s" | tr ' ' '='
        printf "${DIM}%${empty}s${NC}] ${percent}%%" | tr ' ' '-'
        
        timeout 2 bash -c "</dev/tcp/$IP/$PORT" 2>/dev/null
        if [ $? -eq 0 ]; then
            OPEN_PORTS+=($PORT)
            open_count=$((open_count + 1))
            
            # Service detection
            case $PORT in
                22) SERVICE="SSH" ;;
                80) SERVICE="HTTP" ;;
                443) SERVICE="HTTPS" ;;
                3306) SERVICE="MySQL" ;;
                5432) SERVICE="PostgreSQL" ;;
                27017) SERVICE="MongoDB" ;;
                6379) SERVICE="Redis" ;;
                8080) SERVICE="HTTP-Alt" ;;
                8443) SERVICE="HTTPS-Alt" ;;
                9200) SERVICE="Elasticsearch" ;;
                5601) SERVICE="Kibana" ;;
                9090) SERVICE="Prometheus" ;;
                3000) SERVICE="Grafana" ;;
                *) SERVICE="Unknown" ;;
            esac
            
            # Print found port immediately
            echo
            echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   ${GREEN}${CHECK_MARK} Port $PORT ($SERVICE)${NC}"
        fi
    done
    
    # Clear progress line
    echo -e "\n  ${BLUE}${BOX_DRAWING_VERTICAL}   ${GREEN}Scan complete: ${open_count}/${total_ports} ports open${NC}"
    
    # Log open ports count
    log_metric "open_ports" "${#OPEN_PORTS[@]}" "ports"
    
    # Banner grabbing in verbose mode
    if [ ${#OPEN_PORTS[@]} -gt 0 ] && [ "$VERBOSE" = true ]; then
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
        print_status "INFO" "Banner grabbing" "Service fingerprints:"
        for PORT in "${OPEN_PORTS[@]}"; do
            local banner=$(timeout 2 nc -v $IP $PORT 2>&1 | head -n 1)
            if [ -n "$banner" ]; then
                echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   ${DIM}Port $PORT: ${banner:0:60}${NC}"
            fi
        done
    fi
    echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
}

# HTTP/HTTPS Checks (updated with new UI)
check_http() {
    local port=$1
    local protocol=$2
    
    echo -e "\n  ${BLUE}${BOX_DRAWING_VERTICAL}   ${CYAN}${ARROW_MARK} Checking $protocol://$IP:$port${NC}"
    
    # Full HTTP metrics
    local http_metrics=$(curl -o /dev/null -s -w "{
        \"http_code\":%{http_code},
        \"time_total\":%{time_total},
        \"time_connect\":%{time_connect},
        \"time_starttransfer\":%{time_starttransfer},
        \"size_download\":%{size_download},
        \"speed_download\":%{speed_download}
    }" ${protocol}://$IP:$port/ 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$http_metrics" ]; then
        local http_status=$(echo "$http_metrics" | grep -o '"http_code":[0-9]*' | cut -d':' -f2)
        local time_total=$(echo "$http_metrics" | grep -o '"time_total":[0-9.]*' | cut -d':' -f2)
        local time_connect=$(echo "$http_metrics" | grep -o '"time_connect":[0-9.]*' | cut -d':' -f2)
        local time_first_byte=$(echo "$http_metrics" | grep -o '"time_starttransfer":[0-9.]*' | cut -d':' -f2)
        local size=$(echo "$http_metrics" | grep -o '"size_download":[0-9]*' | cut -d':' -f2)
        local speed=$(echo "$http_metrics" | grep -o '"speed_download":[0-9.]*' | cut -d':' -f2)
        
        local response_time=$(echo "$time_total * 1000" | bc 2>/dev/null | cut -d'.' -f1)
        local ttfb=$(echo "$time_first_byte * 1000" | bc 2>/dev/null | cut -d'.' -f1)
        
        # Check HTTP status
        if [ "$http_status" -eq 200 ]; then
            print_status "OK" "HTTP Status: $http_status" "Service responding normally"
        elif [ "$http_status" -ge 500 ]; then
            print_status "FAIL" "HTTP Status: $http_status" "Server Error detected"
            CRITICAL+=("HTTP ${http_status} error on port $port")
        elif [ "$http_status" -ge 400 ]; then
            print_status "WARN" "HTTP Status: $http_status" "Client Error detected"
            WARNINGS+=("HTTP ${http_status} on port $port")
        else
            print_status "INFO" "HTTP Status: $http_status" "Informational response"
        fi
        
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}     ${DIM}Response Time: ${response_time}ms | TTFB: ${ttfb}ms${NC}"
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}     ${DIM}Download: ${size} bytes @ $(echo "$speed / 1024" | bc) KB/s${NC}"
        
        # Log metrics
        log_metric "response_time_$port" "$response_time" "ms"
        log_metric "ttfb_$port" "$ttfb" "ms"
        
        # Check redirects
        if [[ "$http_status" =~ ^30[0-9] ]]; then
            local redirect_url=$(curl -s -I ${protocol}://$IP:$port/ | grep -i "location" | cut -d' ' -f2)
            echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}     ${DIM}Redirects to: $redirect_url${NC}"
        fi
        
        # SSL/TLS checks for HTTPS
        if [ "$protocol" = "https" ]; then
            local ssl_info=$(echo | openssl s_client -servername $TARGET -connect $IP:$port 2>/dev/null | openssl x509 -noout -dates -issuer -subject 2>/dev/null)
            if [ -n "$ssl_info" ]; then
                echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}     ${CYAN}SSL/TLS Info:${NC}"
                
                # Extract expiry date
                local end_date=$(echo "$ssl_info" | grep "notAfter" | cut -d'=' -f2)
                local end_seconds=$(date -d "$end_date" +%s 2>/dev/null)
                local now_seconds=$(date +%s)
                local days_left=$(( ($end_seconds - $now_seconds) / 86400 ))
                
                echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}       ${DIM}Issuer: $(echo "$ssl_info" | grep "issuer" | cut -d'=' -f2 | cut -d',' -f1)${NC}"
                echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}       ${DIM}Expires: $end_date (${days_left} days left)${NC}"
                
                log_metric "ssl_days_left_$port" "$days_left" "days"
            fi
        fi
    else
        print_status "FAIL" "Could not connect to $protocol://$IP:$port" "Service may be down or blocking requests"
    fi
}

# Web Server Analysis (updated with new UI)
check_web() {
    draw_section_header "4. WEB SERVER ANALYSIS" "$BLUE"
    echo -e "${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
    
    local web_ports=()
    for port in "${OPEN_PORTS[@]}"; do
        if [ "$port" -eq 80 ] || [ "$port" -eq 443 ] || [ "$port" -eq 8080 ] || [ "$port" -eq 8443 ]; then
            web_ports+=($port)
        fi
    done
    
    if [ ${#web_ports[@]} -eq 0 ]; then
        print_status "INFO" "No web ports detected" "Skipping web analysis"
    else
        for port in "${web_ports[@]}"; do
            local protocol="http"
            [ "$port" -eq 443 ] || [ "$port" -eq 8443 ] && protocol="https"
            
            # Check main endpoint
            check_http $port $protocol
            
            # Check common health endpoints in verbose mode
            if [ "$VERBOSE" = true ]; then
                for endpoint in "/health" "/healthz" "/ready" "/status" "/metrics"; do
                    local health_check=$(curl -o /dev/null -s -w "%{http_code}" ${protocol}://$IP:$port$endpoint 2>/dev/null)
                    if [ "$health_check" -eq 200 ]; then
                        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}     ${GREEN}${CHECK_MARK} Health endpoint $endpoint accessible${NC}"
                    fi
                done
            fi
        done
    fi
    echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
}

# Security Checks (updated with new UI)
check_security() {
    [ "$NO_SECURITY" = true ] && return
    
    draw_section_header "5. SECURITY CHECKS" "$BLUE"
    echo -e "${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
    
    # Check for open common vulnerable ports
    local vulnerable_ports=(21 23 445 3389 5900)
    local vuln_found=false
    
    for port in "${vulnerable_ports[@]}"; do
        timeout 2 bash -c "</dev/tcp/$IP/$port" 2>/dev/null
        if [ $? -eq 0 ]; then
            if [ "$vuln_found" = false ]; then
                print_status "WARN" "Potentially vulnerable ports open" "Security risk detected"
                vuln_found=true
            fi
            echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}   ${YELLOW}${WARNING_MARK} Port $port is open${NC}"
            WARNINGS+=("Vulnerable port $port is open")
        fi
    done
    
    if [ "$vuln_found" = false ]; then
        print_status "OK" "No vulnerable ports detected" "Common attack surface is minimal"
    fi
    
    # Check for security headers on web servers
    local web_ports=()
    for port in "${OPEN_PORTS[@]}"; do
        if [ "$port" -eq 80 ] || [ "$port" -eq 443 ] || [ "$port" -eq 8080 ] || [ "$port" -eq 8443 ]; then
            web_ports+=($port)
        fi
    done
    
    for port in "${web_ports[@]}"; do
        echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
        local protocol="http"
        [ "$port" -eq 443 ] || [ "$port" -eq 8443 ] && protocol="https"
        
        local headers=$(curl -s -I ${protocol}://$IP:$port/ 2>/dev/null)
        
        local security_headers=(
            "Strict-Transport-Security"
            "X-Frame-Options"
            "X-Content-Type-Options"
            "Content-Security-Policy"
            "X-XSS-Protection"
            "Referrer-Policy"
        )
        
        print_status "INFO" "Security headers on port $port" "Checking for best practices"
        for header in "${security_headers[@]}"; do
            if echo "$headers" | grep -qi "^$header:"; then
                echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}     ${GREEN}${CHECK_MARK} $header present${NC}"
            else
                echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}     ${YELLOW}${WARNING_MARK} $header missing${NC}"
            fi
        done
    done
    echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
}

# Performance Metrics (updated with new UI)
check_performance() {
    draw_section_header "7. PERFORMANCE METRICS" "$BLUE"
    echo -e "${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
    
    # Network throughput test
    if [[ " ${OPEN_PORTS[@]} " =~ " 80 " ]] || [[ " ${OPEN_PORTS[@]} " =~ " 443 " ]]; then
        local protocol="http"
        local port=80
        [[ " ${OPEN_PORTS[@]} " =~ " 443 " ]] && protocol="https" && port=443
        
        local speed_test=$(curl -o /dev/null -s -w "%{speed_download}" ${protocol}://$IP:$port/ 2>/dev/null)
        if [ -n "$speed_test" ] && [ "$speed_test" != "0" ]; then
            local speed_kbps=$(echo "$speed_test / 1024" | bc)
            print_status "INFO" "Download Speed" "${speed_kbps} KB/s"
            log_metric "download_speed" "$speed_kbps" "KB/s"
        fi
    fi
    
    # Connection pooling test
    echo -e "  ${BLUE}${BOX_DRAWING_VERTICAL}${NC}"
    local success=0
    local total=5
    for i in {1..5}; do
        if timeout 1 bash -c "</dev/tcp/$IP/80" 2>/dev/null; then
            success=$((success + 1))
        fi
        sleep 0.1
    done
    local success_rate=$((success * 100 / total))
    
    if [ $success_rate -ge 80 ]; then
        print_status "OK" "Connection pooling" "${success_rate}% success rate (${success}/${total})"
    else
        print_status "WARN" "Connection pooling" "${success_rate}% success rate (${success}/${total})"
        CRITICAL+=("Low connection success rate: ${success_rate}%")
    fi
    log_metric "connection_success_rate" "$success_rate" "%"
    
    echo -e "${BLUE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${NC}"
}

# Generate final report (updated with new UI)
generate_report() {
    calculate_health_score
    
    echo
    echo -e "${PURPLE}${BOX_DRAWING_CORNER_TL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_CORNER_TR}${NC}"
    echo -e "${PURPLE}${BOX_DRAWING_VERTICAL}${NC}${BOLD}${WHITE}                 FINAL REPORT - Check #$CHECK_COUNT                 ${NC}${PURPLE}${BOX_DRAWING_VERTICAL}${NC}"
    echo -e "${PURPLE}${BOX_DRAWING_TEE_LEFT}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_TEE_RIGHT}${NC}"
    
    # Health score gauge
    local gauge_width=50
    local filled=$((HEALTH_SCORE * gauge_width / 100))
    local empty=$((gauge_width - filled))
    
    echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${WHITE}Health Score:${NC} ${BOLD}${HEALTH_SCORE}%${NC}"
    echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  [${GREEN}$(printf "%${filled}s" | tr ' ' '=')${RED}$(printf "%${empty}s" | tr ' ' '=')${NC}]"
    
    # Display critical issues
    if [ ${#CRITICAL[@]} -gt 0 ]; then
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}${NC}"
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${RED}${BOLD}CRITICAL ISSUES:${NC}"
        for critical in "${CRITICAL[@]}"; do
            echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${RED}${CROSS_MARK} ${critical}${NC}"
        done
    fi
    
    # Display warnings
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}${NC}"
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${YELLOW}${BOLD}WARNINGS:${NC}"
        for warning in "${WARNINGS[@]}"; do
            echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${YELLOW}${WARNING_MARK} ${warning}${NC}"
        done
    fi
    
    # Display metrics summary
    if [ ${#METRICS[@]} -gt 0 ]; then
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}${NC}"
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${CYAN}${BOLD}Metrics Summary:${NC}"
        for metric in "${METRICS[@]}"; do
            echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${CYAN}${BULLET_MARK} ${metric}${NC}"
        done
    fi
    
    # Overall status
    echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}${NC}"
    if [ ${#CRITICAL[@]} -eq 0 ] && [ -z "$ISSUE" ]; then
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${GREEN}${BOLD}✅ SYSTEM STATUS: HEALTHY${NC}"
        if [ -n "$SOLUTION" ]; then
            echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${WHITE}Recommendation:${NC} $SOLUTION"
        fi
    else
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${RED}${BOLD}❌ SYSTEM STATUS: ISSUES DETECTED${NC}"
        
        if [ -n "$ISSUE" ]; then
            echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${YELLOW}${BOLD}💡 PRIMARY ISSUE:${NC} $ISSUE"
            echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${YELLOW}${BOLD}💡 RECOMMENDED SOLUTION:${NC}"
            echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}     $SOLUTION"
        fi
        
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
    
    # Uptime tracking
    if [ $CHECK_COUNT -gt 0 ]; then
        local availability=$(( ( (CHECK_COUNT - FAILURE_COUNT) * 100 ) / CHECK_COUNT ))
        echo -e "  ${PURPLE}${BOX_DRAWING_VERTICAL}  ${WHITE}Availability:${NC} ${availability}% (${CHECK_COUNT} checks)"
        log_metric "availability" "$availability" "%"
    fi
    
    echo -e "${PURPLE}${BOX_DRAWING_CORNER_BL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_CORNER_BR}${NC}"
}

# JSON output (unchanged)
generate_json() {
    local status="HEALTHY"
    [ ${#CRITICAL[@]} -gt 0 ] || [ -n "$ISSUE" ] && status="ISSUE"
    
    # Create JSON arrays
    local json_open_ports=$(printf '%s\n' "${OPEN_PORTS[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
    local json_warnings=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
    local json_critical=$(printf '%s\n' "${CRITICAL[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
    local json_metrics=$(printf '%s\n' "${METRICS[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
    
    cat <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "check_number": $CHECK_COUNT,
    "target": "$TARGET",
    "ip": "$IP",
    "status": "$status",
    "health_score": $HEALTH_SCORE,
    "issue": "$ISSUE",
    "solution": "$SOLUTION",
    "open_ports": $json_open_ports,
    "warnings": $json_warnings,
    "critical": $json_critical,
    "metrics": $json_metrics,
    "availability": $(( ( (CHECK_COUNT - FAILURE_COUNT) * 100 ) / CHECK_COUNT ))
}
EOF
}

# ============================================================================
# MAIN MONITORING FUNCTION
# ============================================================================

run_checks() {
    CHECK_COUNT=$((CHECK_COUNT + 1))
    
    # Reset variables for this check
    ISSUE=""
    SOLUTION=""
    WARNINGS=()
    CRITICAL=()
    METRICS=()
    
    # Print header with check number
    clear
    echo -e "${CYAN}${BOX_DRAWING_CORNER_TL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_CORNER_TR}${NC}"
    echo -e "${CYAN}${BOX_DRAWING_VERTICAL}${NC}${BOLD}${WHITE}              SMART SRE NETWORK MONITOR - Check #$CHECK_COUNT              ${NC}${CYAN}${BOX_DRAWING_VERTICAL}${NC}"
    echo -e "${CYAN}${BOX_DRAWING_TEE_LEFT}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_HORIZONTAL}${BOX_DRAWING_TEE_RIGHT}${NC}"
    
    echo -e "  ${CYAN}${BOX_DRAWING_VERTICAL}  ${WHITE}Time:${NC}      $(date)"
    echo -e "  ${CYAN}${BOX_DRAWING_VERTICAL}  ${WHITE}Target:${NC}    $TARGET"
    echo -e "  ${CYAN}${BOX_DRAWING_VERTICAL}  ${WHITE}Thresholds:${NC} Latency(W:$LATENCY_WARN/C:$LATENCY_CRIT) Loss(W:$PACKET_LOSS_WARN/C:$PACKET_LOSS_CRIT)"
    echo -e "  ${CYAN}${BOX_DRAWING_VERTICAL}${NC}"
    
    # Run all checks
    check_dns || return
    check_network || return
    check_ports
    check_web
    check_security
    check_dependencies
    check_performance
    
    # Generate report
    if [ "$JSON_OUTPUT" = true ]; then
        generate_json
    else
        generate_report
    fi
}

# ============================================================================
# SIGNAL HANDLING
# ============================================================================

cleanup() {
    echo -e "\n${YELLOW}${INFO_MARK} Monitoring stopped after $CHECK_COUNT checks${NC}"
    if [ "$JSON_OUTPUT" = true ]; then
        generate_json
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Parse arguments
parse_args "$@"

# Main loop
if [ "$CONTINUOUS_MODE" = true ]; then
    echo -e "${GREEN}${INFO_MARK} Starting continuous monitoring (interval: ${INTERVAL}s)${NC}"
    echo -e "${GREEN}${INFO_MARK} Press Ctrl+C to stop\n"
    
    while true; do
        run_checks
        echo -e "\n${YELLOW}${INFO_MARK} Waiting ${INTERVAL} seconds until next check...\n"
        sleep $INTERVAL
    done
else
    # Single run mode
    run_checks
    
    # Exit with appropriate code
    if [ ${#CRITICAL[@]} -gt 0 ] || [ -n "$ISSUE" ]; then
        exit 2
    elif [ ${#WARNINGS[@]} -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
fi
