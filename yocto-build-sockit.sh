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
# Author: Dan Negvesky <dnegvesky@arrow.com>
# Contributors:
#
# Release info:
#
# 16.1
#   - initial release for Arrow SoCKit GSRD v16.1 release
#
# TODO: add dependecy checking to this sript (currently in yocto-packages.sh because the installation
#       of package, if necessary, requires root privileges); this script cannot run as root
# TODO: add parameters to allow for more build customization (u-boot & kernel version, etc)
#       pass arguments to variables that are written to Yocto config files
# TODO: add better flow control: if BUILD_DIR exists then skip the setup and go right to bitbake
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

check_disk_space()
{
    # assuming OK to work in GB due to large image and HDD sizes
    FREE_SPACE=`df --block-size=1G $PWD | awk '/[0-9]%/{print $(NF-2)}'`

    printf "\nChecking available disk space... "
    if [ "$FREE_SPACE" -lt "$IMG_SIZE" ]; then
        printf "\nAvailable: ${FREE_SPACE} GB\n"
        printf "Required: ${IMG_SIZE} GB\n"
        printf "Please free at least $(($IMG_SIZE - $FREE_SPACE)) GB and then rerun the build script.\n"
        exit 1
    else
        printf "OK\n"
    fi

FREE_SPACE=`df --block-size=1G $PWD | awk '/[0-9]%/{print $(NF-2)}'`

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
IMG_SIZE=75

# Color text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m' # Not good for white terminal background
NC='\033[0m' # No Color

# ensure not running as root
if [ `whoami` = root ] ; then
    printf "\n${RED}ERROR: Do not run this script as root\n\n"
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

# set build parameter variables based on image specified
# IMG_SIZE = size in bytes / (1024 * 1,000,000)
# image sizes are rounded up conservatively
# actual BUILD_DIR folder sizes:
#  - uboot                      = 10,949,536,237 (10.2 GiB)
#  - kernel                     = 13,080,589,500 (12.2 GiB)
#  - arrow-sockit-console-image = 35,017,792,910 (32.6 GiB)
#  - arrow-sockit-xfce-image    = 75,888,997,849 (70.7 GiB)
# these actual image sizes will likely not be updated in new
# releases of the script as this was more of an acedemic exercise

case $BUILD_IMG in
    arrow-sockit-xfce-image)
        IMG_SIZE=75
    ;;
    arrow-sockit-console-image)
        IMG_SIZE=35
    ;;
    uboot)
        BUILD_IMG=virtual/bootloader
        IMG_SIZE=11
        KERNEL_VER=NA
        GHRD_BRANCH=NA
        DISTRO_VER=NA
    ;;
    kernel)
        BUILD_IMG=virtual/kernel
        IMG_SIZE=13
        UBOOT_VER=NA
        GHRD_BRANCH=NA
        DISTRO_VER=NA
    ;;
    *)
        echo ""
        echo "Invalid image name specified.  Use --help for valid image names."
        echo ""
        exit 1
esac

# if BUILD_DIR exists, skip checking disk space because this could be
# adding to a previous build (e.g. bootloader or kernel only),
# assume the check was done then
#echo -e ${WHITE}
if [ ! -d "$BUILD_DIR" ]; then
    check_disk_space
else
    printf "\n${BUILD_DIR} directory already exists.\n"
    printf "Maybe you intended to run this in another directory.\n"
    read -r -p "Continue from previous build? [y/n] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            printf "\n"
        ;;
        *)
            exit 1
        ;;
    esac
fi
#echo -e ${NC}

export IMAGE_ROOTFS_EXTRA_SPACE="1048576"
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE IMAGE_ROOTFS_EXTRA_SPACE"

# print introduction, ask for confirmation
echo -e ${GREEN}
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
printf "      disk space required:  ${BLUE}${IMG_SIZE} GB${GREEN}\n"
printf "  - top build directory:    ${BLUE}${BUILD_DIR}${GREEN}\n"
#printf "  - estimated build time:   ${BLUE}> 4 hours typical (processor dependent)${GREEN}\n"
printf "\n"
printf " If this is your first time using the Yocto Project OpenEmbedded\n"
printf " build system on this computer, it may be necessary to exit this\n"   
printf " script and first install some build tools and essential packages\n"
printf " as documented in the Yocto Project Reference Manual v2.2.  You\n"
printf " should run the ${NC}yocto-packages.sh${GREEN} script with root privileges as\n"
printf " instructed on the rocketboards.org page to check for and install\n"
printf " any missing build tools and packages.\n"
printf "*******************************************************************\n"
printf "\n"
echo -e ${NC}

#echo -e ${WHITE}
echo "Verify build configuration.  Exit and rerun script with --help to make changes."
read -r -p "Continue? [y/n] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        printf "\n"
    ;;
    *)
        exit 1
    ;;
esac
#echo -e ${NC}

# create the BUILD_DIR
mkdir -p $BUILD_DIR && cd $BUILD_DIR

# confirm installation of repo, look in the expected location
#echo -e ${WHITE}
if [ -z `which repo 2>/dev/null` ]; then
    echo "It appears that the repo script is not installed."
    echo "If you know you have it then skip this.  Otherwise,"
    echo "if you're not sure, I can install it for you."
    read -r -p "[Y to install / N to skip] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            printf "Installing repo in ~/bin... \n\n"
            if `mkdir -p ~/bin &&
               PATH=~/bin:$PATH &&
               curl https://mirrors.tuna.tsinghua.edu.cn/git/git-repo > ~/bin/repo &&
               chmod a+x ~/bin/repo > /dev/null`; then
               printf "\ndone\n"
            else
               printf "${RED}ERROR: repo installation failed${NC}\n"
               exit 1
            fi
        ;;
        *)
            printf "Skipping repo install\n"
    esac
fi
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo/'
#echo -e ${NC}

# start a build time counter
SECONDS=0

# start the build process and echo what we are doing
echo -e ${GREEN}
echo "*******************************************************************"
echo " Cloning Angstrom repo...                                          "
echo "*******************************************************************"
echo -e ${NC}

# Clone Angstrom repo
REPOEXIST=0
if [ -d .repo ]; then
	echo -e ${WHITE}
	echo "It seams link there is .repo already."
	read -r -p "Do you want to remove it? [y/n] " response
	case "$response" in
   		[yY][eE][sS]|[yY]) 
	    	rm .repo -rf    
	    ;;
    	*)
        	REPOEXIST=1
	    ;;
	esac
	echo -e ${NC}
fi
if [ $REPOEXIST -eq 0 ]; then
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
printf " Starting bitbake ${NC}${BUILD_IMG}${GREEN}...\n"
echo "*******************************************************************"
echo -e ${NC}

if bitbake $BUILD_IMG ; then
    # display elapsed build time for successful build
    ELAPSED="$(($SECONDS / 3600)) hrs $((($SECONDS / 60) % 60)) min $(($SECONDS % 60)) sec"
    echo -e ${GREEN}
    printf "*******************************************************************\n"
    printf " Build of ${NC}${BUILD_IMG}${GREEN}\n"
    printf " completed successfully in ${NC}${ELAPSED}${GREEN}\n"
    printf " Output files directory:\n"
    printf "\n"
    printf " ${BLUE}${PWD}/deploy/glibc/images/arrow-sockit/${GREEN}\n"
    printf "\n"
    printf " If you built a full image (XFCE or console), you can now copy\n"
    printf " the SD card image file to your micro SD Card:\n"
    printf "  1. Insert your micro SD card into appropriate adapter and plug\n"
    printf "     into USB port or SD card reader port on this PC.\n"
    printf "  2. Determine the SD card mount point by entering a command such\n"
    printf "     as ${NC}lsblk${GREEN} at the prompt below.\n"
    printf "  3. At the prompt, enter the command:\n"
    printf "     ${NC}sudo dd if=${PWD}/deploy/glibc/images/arrow-sockit/${BUILD_IMG}-arrow-sockit.socfpga-sdimg of=/dev/sd${RED}X${NC} bs=1M && sync${GREEN}\n"
    printf "     where ${NC}sd${RED}X${GREEN} is the mount point determined in step 2.\n"
    printf "  4. Eject the SD card from this PC, insert into the SoCKit SD\n"
    printf "     card adapter, and power on the SoCKit.\n"
    printf "*******************************************************************\n"
    printf "\n"
    echo -e ${NC}
else
    echo " It looks like something went wrong with bitbake.  Either you manually"
    echo " interrupted the build process or perhaps a required build tool is    "
    echo " still missing that I was not able to detect for your Linux           "
    echo " distribution.  Please refer to the Yocto Project Reference Manual,   "
    echo " \"Required Packages for Host Development System\" section.           " 
fi
