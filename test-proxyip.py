import os
import shutil
import subprocess
import sys
import requests
from zipfile import ZipFile
import logging

def setup_logging():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def download_file(url, filename):
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        with open(filename, "wb") as f:
            f.write(response.content)
        logging.info(f"Successfully downloaded {filename}")
    except requests.exceptions.RequestException as e:
        logging.error(f"Error downloading file: {e}")
        sys.exit(1)

def extract_zip(zip_file, extract_to):
    try:
        with ZipFile(zip_file, 'r') as zip_ref:
            zip_ref.extractall(extract_to)
        logging.info(f"Successfully extracted {zip_file}")
    except Exception as e:
        logging.error(f"Error extracting zip file: {e}")
        sys.exit(1)

def compile_as_files(folder, output_file):
    with open(output_file, 'w') as outfile:
        for filename in os.listdir(folder):
            if filename.endswith("-1-443.txt"):
                with open(os.path.join(folder, filename), 'r') as infile:
                    outfile.write(infile.read())
    
    if not os.path.exists(output_file) or os.path.getsize(output_file) == 0:
        logging.error("No suitable AS files found or compiled file is empty.")
        sys.exit(1)
    
    logging.info(f"Compiled AS file created: {output_file}")

def run_iptest(raw_file, port, tls_mode, max_ips, outfile, speedtest, limit):
    iptest_path = os.path.join(os.getcwd(), 'iptest.exe')
    if not os.path.exists(iptest_path):
        logging.error("iptest command not found in the current directory.")
        sys.exit(1)

    try:
        cmd = [
            iptest_path,
            f"-file={raw_file}",
            f"-port={port}",
            f"-tls={'true' if tls_mode else 'false'}",
            f"-max={max_ips}",
            f"-outfile={outfile}",
            f"-speedtest={speedtest}"
        ]
        subprocess.run(cmd, check=True)
        logging.info(f"Test completed. Results saved in {outfile}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error occurred during IP testing: {e}")
        sys.exit(1)

def cleanup(folder, file):
    if os.path.exists(folder):
        shutil.rmtree(folder)
    if os.path.exists(file):
        os.remove(file)
    logging.info("Cleanup completed")

def main():
    setup_logging()

    # Fixed values for automatic purposes
    port = 443
    tls_mode = True
    max_ips = 100
    outfile = "ip_filtered.csv"
    speedtest = 2

    raw_zip = "txt.zip"
    raw_zip_folder = "txt"
    raw_file = "ip_raw.txt"

    cleanup(raw_zip_folder, raw_file)

    download_file("https://zip.baipiao.eu.org", raw_zip)
    extract_zip(raw_zip, raw_zip_folder)
    compile_as_files(raw_zip_folder, raw_file)
    run_iptest(raw_file, port, tls_mode, max_ips, outfile, speedtest)

    cleanup(raw_zip_folder, raw_file)
    os.remove(raw_zip)

    logging.info("Script execution completed successfully.")

if __name__ == "__main__":
    main()
