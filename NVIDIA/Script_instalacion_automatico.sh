#!/bin/bash

# 1. Blacklist Nouveau driver
if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist.conf; then
    echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
    reboot
fi

# 2. Add required repositories
echo "deb http://ftp.debian.org/debian bookworm main contrib" >> /etc/apt/sources.list
echo "deb http://ftp.debian.org/debian bookworm-updates main contrib" >> /etc/apt/sources.list
echo "deb http://security.debian.org/debian-security bookworm-security main contrib" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bookworm main contrib non-free-firmware" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware" >> /etc/apt/sources.list

# Update packages and Proxmox
apt update && apt dist-upgrade -y

# Install required packages
apt-get install -y git
apt-get install -qqy pve-headers-`uname -r` gcc make 

# Install NVIDIA drivers
mkdir -p /opt/nvidia
cd /opt/nvidia
latest_driver=$(curl -s https://download.nvidia.com/XFree86/Linux-x86_64/latest.txt)
driver_version=$(basename $latest_driver)
wget $latest_driver/$driver_version/NVIDIA-Linux-x86_64-$driver_version.run
chmod +x NVIDIA-Linux-x86_64-$driver_version.run
./NVIDIA-Linux-x86_64-$driver_version.run --no-questions --ui=none --disable-nouveau
reboot

# Add modules to /etc/modules-load.d/modules.conf
echo "vfio" >> /etc/modules-load.d/modules.conf
echo "vfio_iommu_type1" >> /etc/modules-load.d/modules.conf
echo "vfio_pci" >> /etc/modules-load.d/modules.conf
echo "vfio_virqfd" >> /etc/modules-load.d/modules.conf
echo "nvidia" >> /etc/modules-load.d/modules.conf
echo "nvidia_uvm" >> /etc/modules-load.d/modules.conf

# Update initramfs
update-initramfs -u -k all

# Create udev rules for NVIDIA drivers
cat > /etc/udev/rules.d/70-nvidia.rules <<EOF
KERNEL=="nvidia", RUN+="/bin/bash -c '/usr/bin/nvidia-smi -L'"
KERNEL=="nvidia_uvm", RUN+="/bin/bash -c '/usr/bin/nvidia-modprobe -c0 -u'"
EOF

# Install NVIDIA driver persistence
cd /opt/nvidia
git clone https://github.com/NVIDIA/nvidia-persistenced.git
cd nvidia-persistenced/init
./install.sh
reboot



cd /opt/nvidia
git clone https://github.com/keylase/nvidia-patch.git
cd nvidia-patch
./patch.sh
