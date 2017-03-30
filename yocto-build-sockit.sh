#!/bin/bash
#
# MIT License
# Copyright (c) 2017 Arrow Electronics
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Release info:
#
# v16.1   3/26/2017 dnegvesky
#   - initial release for Arrow SoCKit GSRD v16.1 release
#
#
# TODO: add parameters to allow for build customization; arguments passed to variables that are written to Yocto config files
#

#################################################
# Functions
#################################################

usage()
{
    echo "Usage: ./yocto-build-sockit.sh [options]"
    echo "Yocto build script for Arrow SoCKit"
    echo "Options:"
    echo "  -d, --directory [dir name]     Build directory name"
    echo "                                 If not specified, defaults to"
    echo "                                 angstrom-v2016.12-yocto2.2"
    echo ""
    echo "  -i, --image [image name]       Only these images names are valid:"
    echo "                                   arrow-sockit-xfce-image (XFCE graphical desktop, default if image not specified)"
    echo "                                   arrow-sockit-console-image (console applications only)"
    echo "                                   uboot (builds U-Boot bootloader only)"
    echo "                                   kernel (builds linux kernel only)"
    echo ""
    echo "  -h, --help                     Display this help message and exit."
    echo ""
    echo "  -v, --version                  Display script version info and exit."
    echo ""
}

#################################################
# Main
#################################################

# Configuration variables
SCRIPT_VERSION="Arrow SoCKit GSRD v16.1 Yocto Build Script"
SHORT_VER=16.1
BUILD_DIR=angstrom-v2016.12-yocto2.2
GHRD_BRANCH=arrow-sockit-1080p-16.1
UBOOT_VER=2017.03
KERNEL_VER=4.1.33-ltsi
DISTRO_VER="Angstrom v2016.12"
BUILD_IMG=arrow-sockit-xfce-image
IMG_SIZE="75 GB"

# Formatting variables
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ensure not running as root
if [ `whoami` = root ] ; then
    printf "\n${RED}ERROR: Do not run this script using root privileges${NC}\n\n"
    exit 1
fi

# check arguments
while [ "$1" != "" ]; do
    case $1 in
        -v | --version)
            echo "${SCRIPT_VERSION}"
            exit
        ;;
        -d | --directory)
            shift
            BUILD_DIR=$1
        ;;
        -i | --image)
            shift
            BUILD_IMG=$1
        ;;
        -h | --help)
            usage
            exit
        ;;
        *)
            usage
            exit 1
    esac
    shift
done

# set build parameter variables based on image
case $BUILD_IMG in
    arrow-sockit-xfce-image)
        IMG_SIZE="75 GB"
    ;;
    arrow-sockit-console-image)
        IMG_SIZE="? GB"
    ;;
    uboot)
        BUILD_IMG=virtual/bootloader
        IMG_SIZE="<5 GB"
        KERNEL_VER=NA
        GHRD_BRANCH=NA
        DISTRO_VER=NA
    ;;
    kernel)
        BUILD_IMG=virtual/kernel
        IMG_SIZE="<5 GB"
        UBOOT_VER=NA
        GHRD_BRANCH=NA
        DISTRO_VER=NA
    ;;
    *)
esac

# check if BUILD_DIR exists
echo -e ${WHITE}
if [ -d "$BUILD_DIR" ]; then
    printf "\n${BUILD_DIR} directory already exists.\n"
    printf "If you continue, you could overwrite previous build results.\n"
    read -r -p "Continue? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            printf "\n"
        ;;
        *)
            exit 1
        ;;
    esac
fi
echo -e ${NC}

# print introduction, ask for confirmation
printf ${GREEN}
printf "*******************************************************************\n"
printf " This is the Yocto 2.2 build script for the Arrow SoCKit Dev. Kit\n"
printf " Current build configuration:\n"
#printf " Run script with --help to view customizable perameters.\n"
printf "  - SoCKit GSRD release:    ${BLUE}${SHORT_VER}${GREEN}\n"
printf "  - SoCKit GHRD branch:     ${BLUE}${GHRD_BRANCH}${GREEN}\n"
printf "  - U-Boot version:         ${BLUE}${UBOOT_VER}${GREEN}\n"
printf "  - Kernel version:         ${BLUE}${KERNEL_VER}${GREEN}\n"
printf "  - Distro version:         ${BLUE}${DISTRO_VER}${GREEN}\n"
printf "  - Build image:            ${BLUE}${BUILD_IMG}${GREEN}\n"
printf "      disk space required:  ${BLUE}${IMG_SIZE}${GREEN}\n"
printf "  - output build directory: ${BLUE}${BUILD_DIR}${GREEN}\n"
#printf "  - estimated build time:   ${BLUE}> 4 hours typical (processor dependent)${GREEN}\n"
printf "\n"
printf " If this is your first time using the Yocto Project OpenEmbedded\n"
printf " build system on this computer, it may be necessary to exit this\n"   
printf " script and first install some build tools and essential packages\n"
printf " as documented in the Yocto Project Reference Manual v2.2.  You\n"
printf " should run the yocto-packages.sh script with root privileges as\n"
printf " instructed on the rocketboards.org page to check for and install\n"
printf " any missing build tools and packages.\n"
printf "*******************************************************************\n"
printf "\n"

echo -e ${WHITE}
echo "Verify build configuration.  Exit and rerun script with --help to make changes."
read -r -p "Continue? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        printf "\n"
    ;;
    *)
        exit 1
    ;;
esac

# create the BUILD_DIR
mkdir -p $BUILD_DIR && cd $BUILD_DIR

# confirm installation of repo, look in the expected location
if [ ! -f ~/bin/repo ]; then
    echo "It does not appear that the repo script is installed."
    echo "If you know you have it then skip this.  Otherwise,"
    echo "if you're not sure, I can install it for you."
    read -r -p "[Y to install / N to skip] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            printf "Installing repo in ~/bin... \n\n"
            if `mkdir -p ~/bin &&
               PATH=~/bin:$PATH &&
               curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ~/bin/repo &&
               chmod a+x ~/bin/repo > /dev/null`; then
               printf "\ndone\n"
            else
               printf "${RED}ERROR: repo installation failed\n"
               exit 1
            fi
        ;;
        *)
            printf "Skipping repo install\n"
    esac
fi
echo -e ${NC}

# start the build process and echo what we are doing
echo -e ${GREEN}
echo "*******************************************************************"
echo " Cloning Angstrom repo...                                          "
echo "*******************************************************************"
echo -e ${NC}

# Clone Angstrom repo
if repo init -u git://github.com/Angstrom-distribution/angstrom-manifest -b angstrom-v2016.12-yocto2.2 ; then
    :
else
    echo -e ${RED}
    echo "ERROR: Cloning Angstrom repo failed."
    echo -e ${ORANGE}
    echo "Are you sure you have repo installed?"
    echo "Maybe you need to run yocto-pacakges.sh first."
    echo -e ${NC}
    exit 1
fi

echo -e ${GREEN}
echo "*******************************************************************"
echo " Configuring local manifests...                                    "
echo "*******************************************************************"
echo -e ${NC}

# this is where our custom layers are specified for the repo tool
if wget https://raw.githubusercontent.com/arrow-socfpga/build-scripts/gsrd-16.1/arrow-sockit_manifest.xml ; then
    :
else
    echo -e ${RED}
    echo "ERROR: failed to fetch manifest file"
    echo -e ${NC}
    exit 1
fi

mkdir -p .repo/local_manifests
mv arrow-sockit_manifest.xml .repo/local_manifests
#cp ../../arrow-sockit_manifest.xml .repo/local_manifests

echo -e ${GREEN}
echo "*******************************************************************"
echo " Syncing...                                                        "
echo "*******************************************************************"
echo -e ${NC}

repo sync

echo -e ${GREEN}
echo "*******************************************************************"
echo " Setting up environment...                                         "
echo "*******************************************************************"
echo -e ${NC}

MACHINE=arrow-sockit . ./setup-environment

echo -e ${GREEN}
echo "*******************************************************************"
echo " Updating bblayers.conf...                                         "
echo "*******************************************************************"
echo -e ${NC}

# add custom layer to bblayers.conf
sed --follow-symlinks -i '/meta-96boards/a \ \ \$\{TOPDIR\}\/layers\/meta-arrow-sockit \\' conf/bblayers.conf

# disable meta-photography layer - causing gnome-keyring bitbake error
sed --follow-symlinks -i '/meta-photography/d' conf/bblayers.conf

echo -e ${GREEN}
echo "*******************************************************************"
echo " Starting bitbake...                                               "
echo "*******************************************************************"
echo -e ${NC}

if bitbake $BUILD_IMG ; then
    echo -e ${GREEN}
    echo "*******************************************************************"
    echo " Build completed successfully.  Build output files directory:      "
    echo -e ${BLUE}
    echo " ${PWD}/${BUILD_DIR}/deploy/glibc/images/${MACHINE}/               "
    echo -e ${GREEN}
    echo " If you built a full image (XFCE or console), you can now copy     "
    echo " the .socfpga-sdimg file to your micro SD Card.                    "
    echo "*******************************************************************"
    echo -e ${NC}
fi
