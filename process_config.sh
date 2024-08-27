#!/bin/bash

# Download the latest subscriptions config
curl -s "https://raw.githubusercontent.com/yebekhe/TVC/main/subscriptions/xray/normal/ss" > original_config.txt

# Initialize counters
cf_counter=0
non_cf_counter=0

# Process the config
cat original_config.txt | grep -v '^#' | while IFS= read -r line; do
    # Remove remarks (everything after the trailing #)
    config=$(echo "$line" | cut -d'#' -f1)

    # Check if it's a Cloudflare config
    if echo "$line" | grep -q '🚩CF'; then
        echo "$config#ss-tvc-cf-$((++cf_counter))" >> processed_config/cloudflare_config.txt
    else
        echo "$config#ss-tvc-$((++non_cf_counter))" >> processed_config/non_cloudflare_config.txt
    fi
done

# Clean up
rm original_config.txt
