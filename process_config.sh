#!/bin/bash

set -euo pipefail

# Constants
RAW_CONFIGS_URL="https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/splitted/vmess.txt"
MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.18.7/mihomo-linux-amd64-v1.18.7.gz"
CLASH_CONFIG_URL="https://sub.bonds.id/sub2?target=clash&url=%s&insert=false&config=base%%2Fdatabase%%2Fconfig%%2Fstandard%%2Fstandard_redir.ini&emoji=false&list=false&udp=true&tfo=false&expand=false&scv=true&fdn=false&sort=false&new_name=true"

# Setup environment
SCRIPT_DIR="$(pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/processed_config"
RAW_CONFIGS_FILE="${SCRIPT_DIR}/raw_configs.txt"
UDP_CONFIGS_FILE="${OUTPUT_DIR}/udp_configs.txt"
VMESS_CF_CONFIGS_FILE="${OUTPUT_DIR}/vmess_cf_configs.txt"
VMESS_CONFIGS_FILE="${OUTPUT_DIR}/vmess_configs.txt"
CLASH_CONFIGS_DIR="${SCRIPT_DIR}/clash_configs"
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

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    if [[ -n "${MIHOMO_PID:-}" ]]; then
        kill "${MIHOMO_PID}" 2>/dev/null || true
        wait "${MIHOMO_PID}" 2>/dev/null || true
    fi
    rm -f "${CLASH_CONFIGS_DIR}/config.yaml"
    rm -rf "${CLASH_CONFIGS_DIR}"
    echo "Cleanup completed."
}

# Set trap for cleanup
trap cleanup EXIT

# Create dirs
mkdir -p "${OUTPUT_DIR}"
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

# Test configs for UDP connection and process them
echo "Testing configs for UDP connection and processing them..."
non_cf_count=1
cf_count=1

# Setup files
rm -f "${UDP_CONFIGS_FILE}"
rm -f "${VMESS_CF_CONFIGS_FILE}"
rm -f "${VMESS_CONFIGS_FILE}"
touch "${UDP_CONFIGS_FILE}"
touch "${VMESS_CF_CONFIGS_FILE}"
touch "${VMESS_CONFIGS_FILE}"

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
    
    # Test UDP connection
    if curl -vfk --http3-only --max-time 5 --socks5 "127.0.0.1:7891" "https://cp.cloudflare.com/generate_204"; then
        echo "${line}" >> "${UDP_CONFIGS_FILE}"
        echo "Config passed UDP test"
        
        # Process the config
        decoded=$(echo "${line}" | sed 's/vmess:\/\///g' | base64 -d)
        
        # Check if it's a Cloudflare config
        if echo "${decoded}" | jq -r '.ps' | grep -q "🏁RELAY"; then
            processed=$(echo "${decoded}" | jq --arg count "${cf_count}" '.ps = "vmess-cf-" + $count')
            encoded=$(echo "${processed}" | base64 -w 0)
            echo "vmess://${encoded}" >> "${VMESS_CF_CONFIGS_FILE}"
            cf_count=$((cf_count + 1))
        else
            processed=$(echo "${decoded}" | jq --arg count "${non_cf_count}" '.ps = "vmess-" + $count')
            encoded=$(echo "${processed}" | base64 -w 0)
            echo "vmess://${encoded}" >> "${VMESS_CONFIGS_FILE}"
            non_cf_count=$((non_cf_count + 1))
        fi
    else
        echo "Config failed UDP test"
    fi
    
    # Clean up
    kill "${MIHOMO_PID}"
    wait "${MIHOMO_PID}" 2>/dev/null
    unset MIHOMO_PID
    rm "${CLASH_CONFIGS_DIR}/config.yaml"
done < "${RAW_CONFIGS_FILE}"

echo "Testing and processing completed."
echo "UDP-compatible configs saved to ${UDP_CONFIGS_FILE}"
echo "Cloudflare VMess configs saved to ${VMESS_CF_CONFIGS_FILE}"
echo "Non-Cloudflare VMess configs saved to ${VMESS_CONFIGS_FILE}"
