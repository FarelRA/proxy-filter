import os
import csv
import requests

def get_valid_ips(csv_file):
    valid_ips = []
    with open(csv_file, 'r') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header row
        for row in reader:
            ip = row[0]
            speed = float(row[7].split()[0])
            if speed > 0:
                valid_ips.append(ip)
    return valid_ips

def update_dns_record(ips):
    url = f"https://api.cloudflare.com/client/v4/zones/{os.environ['CLOUDFLARE_ZONE_ID']}/dns_records/{os.environ['CLOUDFLARE_RECORD_ID']}"
    headers = {
        "Authorization": f"Bearer {os.environ['CLOUDFLARE_API_TOKEN']}",
        "Content-Type": "application/json"
    }
    data = {
        "content": ips,
        "name": os.environ['CLOUDFLARE_DOMAIN_NAME'],
        "proxied": False,
        "type": "A",
        "ttl": "60"
    }
    response = requests.put(url, headers=headers, json=data)
    if response.status_code == 200:
        print("DNS record updated successfully")
    else:
        print(f"Failed to update DNS record: {response.text}")
        exit(1)

ips = get_valid_ips('ip_filtered.csv')
if ips:
    update_dns_record(ips)
else:
    print("No valid IPs found")
    exit(1)
