#!/bin/bash

set -euo pipefail

# Constants
RAW_CONFIGS_URL="https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/splitted/vmess.txt"
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.18.7/mihomo-linux-amd64-v1.18.7.gz"
CLASH_CONFIG_URL="https://sub.bonds.id/sub2?target=clash&url=%s&insert=false&config=base%%2Fdatabase%%2Fconfig%%2Fstandard%%2Fstandard_redir.ini&emoji=false&list=false&udp=true&tfo=false&expand=false&scv=true&fdn=false&sort=false&new_name=true"

# Setup environment
SCRIPT_DIR="$(pwd)"
CLASH_CONFIGS_DIR="${SCRIPT_DIR}/clash_configs"
RAW_CONFIGS_FILE="${SCRIPT_DIR}/raw_configs.txt"
UDP_CONFIGS_FILE="${SCRIPT_DIR}/udp_configs.txt"
MIHOMO_BINARY="${SCRIPT_DIR}/mihomo"

# Function to URL encode a string
urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Function to set proxy variables
set_proxy_vars() {
    export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"
    export all_proxy="socks5://127.0.0.1:7891"
    export http_proxy="http://127.0.0.1:7890"
    export {https,ftp,rsync}_proxy="${http_proxy}"
    export {HTTP,HTTPS,FTP,RSYNC}_PROXY="${http_proxy}"
    export ALL_PROXY="${all_proxy}"
}

# Function to unset proxy variables
unset_proxy_vars() {
    unset {no,all,http,https,ftp,rsync}_proxy
    unset {ALL,HTTP,HTTPS,FTP,RSYNC}_PROXY
}

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    if [[ -n "${MIHOMO_PID:-}" ]]; then
        kill "${MIHOMO_PID}" 2>/dev/null || true
        wait "${MIHOMO_PID}" 2>/dev/null || true
    fi
    unset_proxy_vars
	rm -f "${RAW_CONFIGS_FILE}"
    rm -f "${CLASH_CONFIGS_DIR}/config.yaml"
    rm -rf "${CLASH_CONFIGS_DIR}"
    echo "Cleanup completed."
}

# Set trap for cleanup
trap cleanup EXIT

mkdir -p "${CLASH_CONFIGS_DIR}"

# Download the latest subscriptions config
echo "Downloading raw configs..."
curl -sS "${RAW_CONFIGS_URL}" -o "${RAW_CONFIGS_FILE}"

# Download and setup mihomo xclash
if [[ ! -f "${MIHOMO_BINARY}" ]]; then
    echo "Downloading and setting up mihomo xclash..."
    curl -L "${MIHOMO_URL}" | gunzip > "${MIHOMO_BINARY}"
    chmod +x "${MIHOMO_BINARY}"
fi

# Test configs for UDP connection
echo "Testing configs for UDP connection..."
while IFS= read -r line; do
    echo "Testing config: ${line}"
    
    # URL encode the config
    encoded_url=$(urlencode "${line}")
    
    # Convert to Clash format
    clash_config_url=$(printf "${CLASH_CONFIG_URL}" "${encoded_url}")
    curl -sS "${clash_config_url}" -o "${CLASH_CONFIGS_DIR}/config.yaml"
    
    # Start mihomo xclash
    "${MIHOMO_BINARY}" -d "${CLASH_CONFIGS_DIR}" &
    MIHOMO_PID=$!
    sleep 5  # Wait for mihomo to start
    
    # Set proxy variables
    set_proxy_vars
    
    # Test UDP connection
    if curl -vf --http3-only --max-time 4 https://cloudflare.com &> /dev/null; then
        echo "${line}" >> "${UDP_CONFIGS_FILE}"
        echo "Config passed UDP test"
    else
        echo "Config failed UDP test"
    fi
    
    # Clean up
    kill "${MIHOMO_PID}"
    wait "${MIHOMO_PID}" 2>/dev/null
	unset MIHOMO_PID
    unset_proxy_vars
    rm "${CLASH_CONFIGS_DIR}/config.yaml"
done < "${RAW_CONFIGS_FILE}"

echo "Testing completed. UDP-compatible configs saved to ${UDP_CONFIGS_FILE}"
