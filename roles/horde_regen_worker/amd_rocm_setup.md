# ROCm Installation Guide on Ubuntu 22.04

## 1. Clean Install Preparation

After performing a clean installation of Ubuntu 22.04, update your system to ensure all packages are up to date.

### Update your system:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget gnupg2 software-properties-common
```

## 2. Removing All Existing ROCm Files

Before installing ROCm, it's important to remove any existing ROCm files to avoid conflicts.

### Remove all ROCm directories:

```bash
sudo rm -rf /opt/rocm*
```

### Remove any residual ROCm-related packages:

```bash
sudo apt remove --purge rocm rocm-dkms amdgpu-dkms
sudo apt autoremove
```

### Remove any existing ROCm repositories:

```bash
sudo rm /etc/apt/sources.list.d/rocm.list
sudo rm /etc/apt/sources.list.d/amdgpu.list
```

### Remove the ROCm keyring:

```bash
sudo rm -rf /etc/apt/keyrings/rocm.gpg
```

### Remove ROCm-related environment variables:

```bash
sudo rm /etc/profile.d/rocm.sh
sudo rm /etc/ld.so.conf.d/rocm.conf
```

## 3. Registering Repositories

### a. Package Signing Key

Download and convert the package signing key for ROCm and store it in the keyring directory.

#### Create the keyring directory if it doesn't exist:

```bash
sudo mkdir --parents --mode=0755 /etc/apt/keyrings
```

#### Download the key, convert it to a full keyring, and store it in the keyring directory:

```bash
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null
```

_Note: The GPG key may change; ensure it is updated when installing a new release._

### b. Register Kernel-Mode Driver

Add the AMDGPU repository for the driver and update the package list.

#### Add the AMDGPU repository for Ubuntu 22.04 (Jammy):

```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/6.2/ubuntu jammy main" | sudo tee /etc/apt/sources.list.d/amdgpu.list
```

#### Update the package list:

```bash
sudo apt update
```

## 4. Register ROCm Packages

Add the ROCm repository and set package priorities to ensure ROCm packages are preferred.

#### Add the ROCm repository for Ubuntu 22.04 (Jammy):

```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.2 jammy main" | sudo tee --append /etc/apt/sources.list.d/rocm.list
```

#### Set package priorities to ensure ROCm packages are preferred:

```bash
echo -e 'Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600' | sudo tee /etc/apt/preferences.d/rocm-pin-600
```

#### Update the package list:

```bash
sudo apt update
```

## 5. Installing ROCm

### a. Install the Kernel Driver

Install the `amdgpu-dkms` driver and reboot your system.

#### Install the amdgpu-dkms driver:

```bash
sudo apt install amdgpu-dkms
```

#### Reboot the system:

```bash
sudo reboot
```

### b. Install ROCm Packages

After rebooting, install the ROCm software.

#### Install the ROCm software:

```bash
sudo apt install rocm
```

## 6. Complete Post-Installation Steps

### a. Verify ROCm Installation

Ensure that ROCm is installed and functional by checking the ROCm and OpenCL information.

#### Check ROCm installation:

```bash
/opt/rocm/bin/rocminfo
```

#### Check OpenCL support:

```bash
/opt/rocm/bin/clinfo
```

If these commands return information about your GPUs, the ROCm installation is successful.

### b. Fixing Missing DKMS Configuration

Check if the `dkms status` command reports a missing `dkms.conf` file and fix it if necessary.

#### Check DKMS status:

```bash
dkms status
```

#### If there's an error, remove the incorrect DKMS installation and reinstall ROCm:

```bash
sudo rm -rf /var/lib/dkms/amdgpu/6.7.0-1781449.22.04/
sudo apt install --reinstall rocm-dkms
```

## 7. Setting Up Environment Variables

Add the necessary ROCm environment variables to your system profile.

#### Add ROCm binaries to the system PATH:

```bash
echo 'export PATH=$PATH:/opt/rocm/bin' | sudo tee -a /etc/profile.d/rocm.sh
```

#### Add ROCm libraries to the library path:

```bash
echo '/opt/rocm/lib' | sudo tee /etc/ld.so.conf.d/rocm.conf
echo '/opt/rocm/lib64' | sudo tee -a /etc/ld.so.conf.d/rocm.conf
```

#### Reload the library path:

```bash
sudo ldconfig
```

## 8. Resolving Python Virtual Environment Issues

### a. Install Python Virtual Environment Support

#### Install the `python3.10-venv` package if you encounter issues when trying to create a Python virtual environment:

```bash
sudo apt install python3.10-venv
```

### b. Create and Activate a Python Virtual Environment

#### Create a Python virtual environment:

```bash
python3 -m venv ~/rocm_inv
```

#### Activate the virtual environment:

```bash
source ~/rocm_inv/bin/activate
```

## 9. Final Verification and Running Scripts

Ensure that your setup is working by running scripts in the correct environment.

#### Activate the virtual environment:

```bash
source ~/rocm_inv/bin/activate
```

#### Set the visible GPU device (optional if using multiple GPUs):

```bash
export ROCR_VISIBLE_DEVICES=0  # or whichever GPU you want to use
```

#### Run your Python script:

```bash
python /path/to/your_script.py
```

To verify that the Python script utilizes ROCm correctly, check GPU availability within the script:

```python
import torch
print(torch.cuda.is_available())
print(torch.cuda.device_count())
```

## 10. Checking and Removing Incorrect ROCm Versions

If `/opt/rocm/bin/clinfo` shows the wrong version, check the currently installed ROCm version and remove the incorrect version folder.

#### Check the currently installed ROCm version:

```bash
ls /opt/rocm*
```

#### If an incorrect version is installed, remove it:

```bash
sudo rm -rf /opt/rocm-X.X.X  # Replace X.X.X with the incorrect version number
```

#### Ensure only the correct version remains:

```bash
ls /opt/rocm*
```

## 11. Purging a Failed ROCm Installation

If the ROCm installation fails and you need to start over, purge the installation completely.

#### Remove all ROCm packages:

```bash
sudo apt remove --purge rocm rocm-dkms amdgpu-dkms
```

#### Clean up any residual packages:

```bash
sudo apt autoremove
```

#### Remove the ROCm repositories:

```bash
sudo rm /etc/apt/sources.list.d/rocm.list
sudo rm /etc/apt/sources.list.d/amdgpu.list
```

#### Remove the keyring directory if no other keys are stored there:

```bash
sudo rm -rf /etc/apt/keyrings/rocm.gpg
```

#### Remove ROCm-related environment variables:

```bash
sudo rm /etc/profile.d/rocm.sh
sudo rm /etc/ld.so.conf.d/rocm.conf
```

#### Clean up the /opt directory if necessary:

```bash
sudo rm -rf /opt/rocm*
```

## Conclusion

By following these steps, you should have a fully functional ROCm installation on your Ubuntu 22.04 system. This guide covers registering repositories, installing ROCm, setting up environment variables, checking and removing incorrect versions, and purging a failed installation to ensure a clean environment.
