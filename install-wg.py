import os
import sys
import subprocess
import urllib.request
import logging
from datetime import datetime

# Setup logging
log_file = os.path.join(os.environ['TEMP'], 'wireguard_install.log')
logging.basicConfig(filename=log_file, level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

# Variables
DOWNLOAD_URL = "https://download.wireguard.com/windows-client/wireguard-installer.exe"
INSTALLER_NAME = "wireguard-installer.exe"
INSTALL_DIR = os.path.join(os.environ['PROGRAMFILES'], "WireGuard")

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def download_installer():
    temp_path = os.path.join(os.environ['TEMP'], INSTALLER_NAME)
    logging.info(f"Downloading WireGuard installer to {temp_path}")
    try:
        urllib.request.urlretrieve(DOWNLOAD_URL, temp_path)
        logging.info("Download completed successfully")
        return temp_path
    except Exception as e:
        logging.error(f"Failed to download installer: {e}")
        return None

def install_wireguard(installer_path):
    logging.info("Starting WireGuard installation")
    try:
        subprocess.run([installer_path, '/quiet', '/norestart'], check=True)
        logging.info("WireGuard installation completed")
        return True
    except subprocess.CalledProcessError as e:
        logging.error(f"Installation failed: {e}")
        return False

def verify_installation():
    executable_path = os.path.join(INSTALL_DIR, "wireguard.exe")
    if os.path.exists(executable_path):
        logging.info("WireGuard installation verified")
        return True
    else:
        logging.error("WireGuard executable not found")
        return False

def main():
    if not is_admin():
        logging.error("This script must be run with administrator privileges")
        print("This script must be run with administrator privileges")
        sys.exit(1)

    installer_path = download_installer()
    if not installer_path:
        sys.exit(1)

    if install_wireguard(installer_path):
        if verify_installation():
            logging.info("WireGuard installation successful")
            print("WireGuard has been successfully installed")
        else:
            logging.warning("Installation completed but verification failed")
            print("Installation completed but verification failed. Check the log for details")
    else:
        logging.error("WireGuard installation failed")
        print("WireGuard installation failed. Check the log for details")

    # Clean up
    try:
        os.remove(installer_path)
        logging.info("Installer file removed")
    except Exception as e:
        logging.warning(f"Failed to remove installer file: {e}")

if __name__ == "__main__":
    main()
