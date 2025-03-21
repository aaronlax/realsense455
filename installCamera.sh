#!/bin/bash
# Intel RealSense D435/D455 installation script for Raspberry Pi 5
# Created based on latest available information - March 2025

# Exit on error
set -e

echo "Intel RealSense Installation for Raspberry Pi 5"
echo "----------------------------------------------"
echo "This script will install the Intel RealSense SDK on your Raspberry Pi 5"
echo "Please ensure you're running this script with sudo"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

# Step 1: Update the system
echo "Step 1: Updating system packages..."
apt update
apt upgrade -y

# Step 2: Install dependencies
echo "Step 2: Installing dependencies..."
apt install -y git cmake libssl-dev libusb-1.0-0-dev pkg-config libgtk-3-dev
apt install -y libglfw3-dev libgl1-mesa-dev libglu1-mesa-dev
apt install -y python3-dev python3-pip

# Create a swap file (necessary for compilation)
echo "Setting up swap file (needed for compilation)..."
if [ ! -f /swapfile ]; then
  echo "Creating 2GB swap file..."
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
  echo "Swap file created and enabled"
else
  echo "Swap file already exists, verifying size..."
  SWAP_SIZE=$(stat -c %s /swapfile)
  if [ $SWAP_SIZE -lt 2147483648 ]; then  # Less than 2GB
    echo "Existing swap file is too small, resizing to 2GB..."
    swapoff /swapfile
    rm /swapfile
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
  else
    echo "Swap file is adequate"
  fi
fi

# Step 3: Clone librealsense repository
echo "Step 3: Cloning librealsense repository..."
cd ~
if [ -d "librealsense" ]; then
  echo "Existing librealsense directory found, updating..."
  cd librealsense
  git pull
else
  echo "Cloning fresh copy of librealsense..."
  git clone https://github.com/IntelRealSense/librealsense.git
  cd librealsense
fi

# Step 4: Install udev rules
echo "Step 4: Setting up udev rules..."
cp config/99-realsense-libusb.rules /etc/udev/rules.d/
udevadm control --reload-rules && udevadm trigger

# Step 5: Build and install the SDK
echo "Step 5: Building SDK (this may take a while)..."
mkdir -p build && cd build

# Configure with specific flags for Pi 5
echo "Configuring cmake..."
cmake .. -DBUILD_EXAMPLES=true \
         -DCMAKE_BUILD_TYPE=Release \
         -DFORCE_RSUSB_BACKEND=true \
         -DBUILD_WITH_CUDA=false \
         -DBUILD_PYTHON_BINDINGS=true \
         -DPYTHON_EXECUTABLE=$(which python3)

# Build (limit to 2 cores to avoid memory issues)
echo "Building (this will take some time)..."
make -j2
make install

# Step 6: Update library path
echo "Step 6: Updating library path..."
echo '/usr/local/lib' > /etc/ld.so.conf.d/realsense.conf
ldconfig

# Step 7: Install Python wrapper
echo "Step 7: Installing Python wrapper..."
cd ~/librealsense/build/wrappers/python
pip3 install .

# Step 8: Testing installation
echo "Step 8: Testing installation..."
echo "import pyrealsense2 as rs" > /tmp/test_rs.py
echo "try:" >> /tmp/test_rs.py
echo "    p = rs.pipeline()" >> /tmp/test_rs.py
echo "    print('RealSense SDK installed successfully!')" >> /tmp/test_rs.py
echo "except Exception as e:" >> /tmp/test_rs.py
echo "    print(f'Error: {e}')" >> /tmp/test_rs.py

echo "Running test script..."
python3 /tmp/test_rs.py

echo "Installation complete!"
echo "Try running 'realsense-viewer' to test your camera"
echo ""
echo "TROUBLESHOOTING NOTE:"
echo "If you encounter 'wait_for_frames() RuntimeError: Frame didn't arrive within 5000',"
echo "try increasing the frame timeout when calling wait_for_frames():"
echo "frames = pipeline.wait_for_frames(timeout_ms=15000)  # Increase timeout to 15 seconds"
echo ""
echo "You may also need to modify your import statement to:"
echo "import pyrealsense2.pyrealsense2 as rs  # instead of 'import pyrealsense2 as rs'"