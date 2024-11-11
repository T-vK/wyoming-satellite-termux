#!/data/data/com.termux/files/usr/bin/sh

echo "Enter home directory"
cd ~

echo "Update packages and index"
pkg up

echo "Ensure wget is available..."
if ! command -v wget > /dev/null 2>&1; then
    echo "Installing wget..."
    pkg i -y wget
    if ! command -v wget > /dev/null 2>&1; then
        echo "ERROR: Failed to install wget" >&2
        exit 1
    fi
fi

echo "Clean up potential garbage that might otherwise get in the way..."
wget -qO- https://raw.githubusercontent.com/T-vK/wyoming-satellite-termux/refs/heads/main/uninstall.sh | bash

echo "Ensure sox is available..."
if ! command -v rec > /dev/null 2>&1; then
    echo "Installing sox..."
    pkg i -y sox
    if ! command -v rec > /dev/null 2>&1; then
        echo "ERROR: Failed to install sox (rec not found)" >&2
        exit 1
    fi
    if ! command -v play > /dev/null 2>&1; then
        echo "ERROR: Failed to install sox (play not found)" >&2
        exit 1
    fi
fi

echo "Ensure termux-api is available..."
if ! command -v termux-microphone-record > /dev/null 2>&1; then
    echo "Installing termux-api..."
    pkg i -y termux-api
    if ! command -v termux-microphone-record > /dev/null 2>&1; then
        echo "ERROR: Failed to install termux-api (termux-microphone-record not found)" >&2
        exit 1
    fi
fi

echo "Checking if Linux kernel supports memfd..."
KERNEL_MAJOR_VERSION="$(uname -r | awk -F'.' '{print $1}')"
if [ $KERNEL_MAJOR_VERSION -le 3 ]; then
    echo "Your kernel is too old to support memfd."
    echo "Installing a custom build of pulseaudio that doesn't depend on memfd..."
    export ARCH="$(termux-info | grep -A 1 "CPU architecture:" | tail -1)"
    echo "Checking if pulseaudio is currently installed..."
    if command -v pulseaudio > /dev/null 2>&1; then
        echo "Uninstalling pulseaudio..."
        pkg remove -y pulseaudio
    fi
    echo "Downloading pulseaudio build that doesn't require memfd..."
    wget -O ./pulseaudio-without-memfd.deb "https://github.com/T-vK/pulseaudio-termux-no-memfd/releases/download/1.1.0/pulseaudio_17.0-2_${ARCH}.deb"
    echo "Installing the downloaded pulseaudio build..."
    pkg i -y ./pulseaudio-without-memfd.deb
    echo "Removing the downloaded pulseaudio build (not required after installation)..."
    rm -f ./pulseaudio-without-memfd.deb
else
    if ! command -v pulseaudio > /dev/null 2>&1; then
        pkg i -y pulseaudio
    fi
fi

if ! command -v pulseaudio > /dev/null 2>&1; then
    echo "ERROR: Failed to install pulseaudio..." >&2
    exit 1
fi

echo "Starting test recording to trigger mic permission prompt..."
echo "(It might ask you for mic access now. Select 'Always Allow'.)"
termux-microphone-record -f ./tmp.wav

echo "Quitting the test recording..."
termux-microphone-record -q

echo "Deleting the test recording..."
rm -f ./tmp.wav

echo "Temporarily load PulseAudio module for mic access..."
if ! pactl list short modules | grep "module-sles-source" ; then
    if ! pactl load-module module-sles-source; then
        echo "ERROR: Failed to load module-sles-source" >&2
    fi
fi

echo "Verify that there is at least one microphone detected..."
if ! pactl list short sources | grep "module-sles-source.c" ; then
    echo "ERROR: No microphone detected" >&2
fi

echo "Cloning Wyoming Satellite repo..."
git clone https://github.com/rhasspy/wyoming-satellite.git

echo "Enter wyoming-satellite directory..."
cd wyoming-satellite

echo "Running Wyoming Satellite setup script..."
./script/setup

echo "Write down the IP address (most likely starting with '192.') of your device, you should find it in the following output:"
ifconfig

echo "Setting up autostart..."
mkdir -p ~/.termux/boot/
wget -P ~/.termux/boot/ "https://raw.githubusercontent.com/T-vK/wyoming-satellite-termux/refs/heads/main/wyoming-satellite-android"
chmod +x ~/.termux/boot/wyoming-satellite-android

echo "Setting up widget shortcut..."
mkdir -p ~/.shortcuts/tasks/
ln -s ../../.termux/boot/wyoming-satellite-android ./wyoming-satellite-android

echo "Successfully installed and set up Wyoming Satellite"

echo "Starting it now..."
~/.termux/boot/wyoming-satellite-android