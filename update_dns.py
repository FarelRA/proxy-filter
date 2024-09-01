import os
import csv
import requests
from typing import List, Dict, Optional

def get_valid_ips(csv_file: str) -> List[str]:
    valid_ips = set()
    try:
        with open(csv_file, encoding='utf-8') as f:
            reader = csv.reader(f)
            next(reader)  # Skip header row
            for row in reader:
                if len(row) >= 8:
                    ip = row[0]
                    try:
                        speed = float(row[7].split()[0])
                        if speed > 0:
                            valid_ips.add(ip)
                    except ValueError:
                        print(f"Invalid speed value for IP {ip}")
                else:
                    print(f"Invalid row format: {row}")
    except FileNotFoundError:
        print(f"CSV file not found: {csv_file}")
    except Exception as e:
        print(f"Error reading CSV file: {e}")
    return list(valid_ips)

def load_existing_records(file_name: str) -> List[Dict[str, str]]:
    existing_records = []
    try:
        with open(file_name, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                existing_records.append({'id': row['Record ID'], 'ip': row['IP']})
    except FileNotFoundError:
        print(f"Records file not found: {file_name}")
    except Exception as e:
        print(f"Error reading records file: {e}")
    return existing_records

def save_records(file_name: str, records: List[Dict[str, str]]):
    try:
        with open(file_name, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['Record ID', 'IP'])
            writer.writeheader()
            for record in records:
                writer.writerow({'Record ID': record['id'], 'IP': record['ip']})
    except Exception as e:
        print(f"Error saving records: {e}")

def cloudflare_api_call(method: str, url: str, data: Optional[Dict] = None) -> Optional[Dict]:
    headers = {
        "Content-Type": "application/json",
        "X-Auth-Email": os.environ['CLOUDFLARE_EMAIL'],
        "X-Auth-Key": os.environ['CLOUDFLARE_API_KEY']
    }
    try:
        response = requests.request(method, url, json=data, headers=headers)
        response.raise_for_status()
        return response.json()['result']
    except requests.exceptions.RequestException as e:
        print(f"API call failed: {e}")
        return None

def create_dns_record(ip: str) -> Optional[str]:
    url = f"https://api.cloudflare.com/client/v4/zones/{os.environ['CLOUDFLARE_ZONE_ID']}/dns_records"
    data = {
        "content": ip,
        "name": os.environ['CLOUDFLARE_DOMAIN_NAME'],
        "type": "A"
    }
    result = cloudflare_api_call('POST', url, data)
    return result['id'] if result else None

def update_dns_record(record_id: str, ip: str) -> bool:
    url = f"https://api.cloudflare.com/client/v4/zones/{os.environ['CLOUDFLARE_ZONE_ID']}/dns_records/{record_id}"
    data = {
        "content": ip,
        "name": os.environ['CLOUDFLARE_DOMAIN_NAME'],
        "type": "A"
    }
    return cloudflare_api_call('PUT', url, data) is not None

def delete_dns_record(record_id: str) -> bool:
    url = f"https://api.cloudflare.com/client/v4/zones/{os.environ['CLOUDFLARE_ZONE_ID']}/dns_records/{record_id}"
    return cloudflare_api_call('DELETE', url) is not None

def main():
    records_file = 'dns_records.csv'
    existing_records = load_existing_records(records_file)
    valid_ips = get_valid_ips('ip_filtered.csv')

    if not valid_ips:
        print("No valid IPs found")
        return

    updated_records = []

    # Update existing records and create new ones if needed
    for i, ip in enumerate(valid_ips):
        if i < len(existing_records):
            # Update existing record
            record = existing_records[i]
            if record['ip'] != ip:
                if update_dns_record(record['id'], ip):
                    updated_records.append({'id': record['id'], 'ip': ip})
                else:
                    print(f"Failed to update record {record['id']} with IP {ip}")
            else:
                updated_records.append(record)
        else:
            # Create new record
            new_record_id = create_dns_record(ip)
            if new_record_id:
                updated_records.append({'id': new_record_id, 'ip': ip})
            else:
                print(f"Failed to create new record for IP {ip}")

    # Delete excess records
    for record in existing_records[len(valid_ips):]:
        if not delete_dns_record(record['id']):
            print(f"Failed to delete record {record['id']}")

    save_records(records_file, updated_records)
    print(f"DNS records updated successfully. Total records: {len(updated_records)}")

if __name__ == "__main__":
    main()
