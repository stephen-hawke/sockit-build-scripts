#! /bin/sh
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
# v1.0
#   - initial release for Yocto Project 2.2 release
#
# 3/30/2017 - tested with Ubuntu 16.04
# 3/30/2017 - tested with Ubuntu 14.04
# 5/11/2017 - tested with CentOS 7-1611
# 5/19/2017 - tested with openSUSE 42.2

#################################################
# Functions
#################################################

usage()
{
    echo ""
    echo "Usage: ./yocto_packages [option] (requires root privileges)"
    echo "Check for and install Yocto Project 2.2 essential packages"
    echo "Options:"
    echo "  -n, --no-install               Dry run; check for packages but do not install"
    echo ""
    echo "  -d [name], --distro [name]     Specify your distribution name (if auto-detect fails)"
    echo "                                 Currently supported distributions:"
    echo "                                 name = Ubuntu, Debian, Fedora, CentOS, or OpenSUSE"
    echo ""
}

check_distro ()
{
    printf "\nDetecting distribution...\n"

    # lsb_release might not work on all distros, so check for "command not found" error
    lsb_release -is 2> /dev/null
    if [ "$?" == "127" ]; then  # exit code 127 = command not found
         echo "your Linux distribution was not detected."        
         echo "Try re-running with the -d option, or -h for help."
         exit 1
    else
        DISTRO=$(lsb_release -is)
    fi
}

check_package () 
{
    printf "Checking for $1... "
    case "$DISTRO" in
        "Ubuntu" | "Debian")
            if `dpkg -s $1 2> /dev/null | grep "Status: install ok installed" > /dev/null`; then
                printf "installed\n"
            else
                printf "not installed\n"
                install_package $1
            fi
        ;;
        "Fedora" | "CentOS")
            if `yum -q info $1 | grep "Installed" > /dev/null`; then
                printf "installed\n"
            else
                printf "not installed\n"
                install_package $1
            fi
        ;;
        "OpenSUSE" | "openSUSE" | "openSUSE project")
            if `zypper info $1 | grep "Installed[[:space:]]\{2,\}:[[:space:]]Yes" > /dev/null`; then
                printf "installed\n"
            else
                printf "not installed\n"
                install_package $1
            fi
        ;;
        *)
            exit 1
        ;;
    esac
}

install_package ()
{
    if $install; then
        printf "Installing $1... "
        case "$DISTRO" in
            "Ubuntu" | "Debian")
                if `apt-get -qq -y install $1 > /dev/null`; then
                    printf "done\n"
                fi
            ;;
            "Fedora" | "CentOS")
                if `yum -q -y install $1`; then
                    printf "done\n"
                fi
            ;;
            "OpenSUSE" | "openSUSE" | "openSUSE project")
                if `zypper -qn install $1 > /dev/null`; then
                    printf "done\n"
                fi
            ;;
            *)
                exit 1
            ;;
        esac
    fi
}

#################################################
# Main
#################################################

install=true
distro_check=true
DISTRO=

# check arguments
while [ "$1" != "" ]; do
    case $1 in
        -n | --no-install)
            install=false
        ;;
        -d | --distro)
            shift
            DISTRO=$1
            distro_check=false
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

if [ `whoami` != root ] ; then
    echo "Error: Package installation requires root privileges.  Please rerun with root privileges."
    exit 1
fi

if $distro_check ; then
    check_distro
else
    echo "Skipping distribution detection... user specified ${DISTRO}"
fi

case "$DISTRO" in
    "Ubuntu" | "Debian")
        # Essentials
        check_package 'gawk' 
        check_package 'wget'
        check_package 'git-core' 
        check_package 'diffstat'
        check_package 'unzip'
        check_package 'texinfo'
        check_package 'gcc-multilib'
        check_package 'build-essential'
        check_package 'chrpath'
        check_package 'socat'
        # Graphics or Eclipse support
        check_package 'libsdl1.2-dev'
        check_package 'xterm'
        # Other
        check_package 'curl'
    ;;
    "Fedora")
        # Essentials
        check_package 'gawk' 
        check_package 'make'
        check_package 'wget'
        check_package 'tar'
        check_package 'bzip2'
        check_package 'gzip'
        check_package 'python3'
        check_package 'unzip'
        check_package 'perl'
        check_package 'patch'
        check_package 'diffutils'
        check_package 'diffstat'
        check_package 'git'
        check_package 'cpp'
        check_package 'gcc'
        check_package 'gcc-c++'
        check_package 'glibc-devel'
        check_package 'texinfo'
        check_package 'chrpath'
        check_package 'ccache'
        check_package 'perl-Data-Dumper'
        check_package 'perl-Text-ParseWords'
        check_package 'perl-Thread-Queue'
        check_package 'perl-bignum'
        check_package 'socat'
        # Graphics or Eclipse support
        check_package 'SDL-devel'
        check_package 'xterm'
        # Other
        check_package 'curl'
    ;;
    "OpenSUSE" | "openSUSE" | "openSUSE project")
        # Essentials
        check_package 'gcc' 
        check_package 'gcc-c++'
        check_package 'git'
        check_package 'chrpath'
        check_package 'make'
        check_package 'wget'
        check_package 'python-xml'
        check_package 'diffstat'
        check_package 'makeinfo'
        check_package 'python-curses'
        check_package 'patch'
        check_package 'socat'
        # Graphics or Eclipse support
        check_package 'libSDL-devel'
        check_package 'xterm'
        # Other
        check_package 'curl'
    ;;
    "CentOS")
        # Essentials
        check_package 'gawk' 
        check_package 'make'
        check_package 'wget'
        check_package 'tar' 
        check_package 'bzip2'
        check_package 'gzip'
        check_package 'python'
        check_package 'unzip'
        check_package 'perl'
        check_package 'patch'
        check_package 'diffutils'
        check_package 'diffstat'
        check_package 'git'
        check_package 'cpp'
        check_package 'gcc'
        check_package 'gcc-c++'
        check_package 'glibc-devel'
        check_package 'texinfo'
        check_package 'chrpath'
        check_package 'socat'
        check_package 'perl-Data-Dumper'
        check_package 'perl-Text-ParseWords'
        check_package 'perl-Thread-Queue'
        # Graphics or Eclipse support
        check_package 'SDL-devel'
        check_package 'xterm'
        # Other
        check_package 'curl'
    ;;
    *)
        echo ""
        echo "Linux distribution not detected or not supported."
        echo "Please try using the --help option or refer to the"
        echo "latest Yocto Project Reference Manual found at"
        echo "http://www.yoctoproject.org"
        echo ""
        exit 1
    ;;
esac
