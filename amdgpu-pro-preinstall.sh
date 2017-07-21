#!/bin/sh

#CHANGELOG v1.4 - 2017/06/22
# Fix 'not registered' check in install_from_media_RHEL() for RHEL6.9


#CHANGELOG v1.3 - 2016/12/08
# Fix script error for RHEL6.8/CentOS6.8
# Check if kernel & kernel-devel version miss match on RHEL/CentOS


#CHANGELOG v1.2 - 2016/12/06
# Added support for SLES 12


#CHANGELOG v1.1 - 2016/10/28
# Added optional commandline parameter "--checkonly"- will only check if required repositories are not set up.
# Fixed bug in makerepo to prevent crash on RHEL 6.8

usage() {
	cat <<END_USAGE
Usage: sudo sh amdgpu-pro-preinstall.sh [options...]

Options:
  -h|--help  		Display this help message
  --check    		Only checks for prerequisities. No system changes are made.

  Unless either of these options are present, the script will build prequisite
  repositories for the amdgpu-pro driver installation.
    
The amdgpu-pro driver requires access to specific RPMs from $ID installation 
media and $extra. This script will confirm that all required prerequisite
files and repositories are available in order to successfully install the 
amdgpu-pro driver.

END_USAGE
}
function find_mountpoint(){
    
    lsblk -l -o mountpoint | while read mnt; do
        if [ -f "$mnt/media.repo" ] && grep -q "name=Red Hat" "$mnt/media.repo" ; then
            echo "\"$mnt\""
            return 0
        elif [ -f "$mnt/media.1/media" ] && grep -q "SUSE" "$mnt/media.1/media"; then
            echo "$mnt"
            return 0
        fi
    done
    return 1
}
function makerepo() {
	
    local mnt=$(find_mountpoint)
    while [[ -z "$mnt" ]]
    do 
        echo -e "$ID install media was not found.\nPlease insert the $ID install media (DVD, USB or a mounted ISO)\nand press ENTER after it has mounted." >&2 
        read
        mnt=$(find_mountpoint)
    done

    
    echo
	echo Installation Media found at $mnt

	echo -e `\
			`"[$ID-install-media]\n"`
			`"Name=$ID Install Media Repository\n"`
			`"baseurl=file://$mnt/\n"`
			`"enabled=1\n"`
			`"gpgcheck=0\n" \
		| $SUDO tee $(dnf_repo)
}

function install_from_media_RHEL() {
    
    if [ $ID != "rhel" ] ; then
        return
    fi
    
    echo "Now checking for Red Hat subscription or a mounted Installation Media..."
    echo
    message=""
    local unregistered="This system is not registered .*\. You can use subscription-manager to register"
    local repolist=$($SUDO yum repolist)

    if [[ $(echo $repolist | awk "/$unregistered/ && ! /$ID-install-media/") ]] ; then
        if $checkonly; then
            echo -e "WARNING: ${unregistered%%.*}\n\t Insert the installation media and rerun the script." >&2
            echo
            err=true
        else
            makerepo 
            message="Please keep the installation media mounted until driver installation is complete."	
        fi
    fi
}

function install_from_media_SUSE() {
    
    if [ $ID == "opensuse" ] ; then
        return
    fi
    
    echo "Now checking for $name subscription or a mounted Installation Media..."
    echo
    message=""
    local repolist=$($SUDO zypper lr)
    if [[ $(SUSEConnect -s | grep "Not Registered") ]] && [[ $(echo $repolist | grep -v "$ID-install-media") ]]; then
        if $checkonly; then
            echo -e "WARNING: This system is not registered.\n\t Insert the installation media and rerun the script." >&2
            echo
            err=true
        else
            makerepo 
            message="Please keep the installation media mounted until driver installation is complete."	
        fi
    fi
}

function install_epel_rhel7() {
	
    echo "EPEL was not found.  Now installing latest EPEL-release"
	$SUDO yum -y localinstall  http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
}

function install_epel_rhel6() {
	
    echo "EPEL was not found.  Now installing latest EPEL-release"
	$SUDO yum -y localinstall http://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
}

function install_extrapkgs_RHEL() {
    
    if ! rpm --quiet -q epel-release ; then
        if $checkonly; then
            echo "WARNING: EPEL is not installed and will need to be installed" >&2
            echo
            err=true
        elif grep -q -i "release 6" /etc/redhat-release ; then
            install_epel_rhel6 
        elif grep -q -i "release 7" /etc/redhat-release ; then
            install_epel_rhel7 
        else
            echo "/etc/redhat-release not found. Unsupported OS." >&2
            exit 1
        fi
    fi

    local kernel_ver=`uname -r`
    yum list all kernel-devel-$kernel_ver 1>/dev/null 2>/dev/null
    if [ $? -gt 0 ]; then
        err=true
        echo "WARNING: no kernel-devel-$kernel_ver package available on the local system or download server!"
        echo "         Please either:"
        echo "           1. install kernel-devel-$kernel_ver, or"
        echo "           2. update your kernel using 'yum update kernel', reboot and try again"
        echo
    fi
}

function install_extrapkgs_SUSE() {
    
    local repolist=$($SUDO zypper lr)
    if [[ $(echo $repolist | grep -v "Bumblebee-Project") ]]; then
        
        if $checkonly; then
        
            echo "WARNING: Bumblebee repository is required to install DKMS and will need to be setup" >&2
            echo
            err=true
        
        else
            
            local bumblebee_repo="/etc/zypp/repos.d/bumblebee.repo"
            
            $SUDO sed -i -e 's/^\(allow_unsupported_modules\).*$/\1 1/' /etc/modprobe.d/10-unsupported-modules.conf 
    
            echo -e `\
                        `"[Bumblebee-Project]\n"`
                        `"Name=Bumblebee-Project for DKMS\n"`
                        `"baseurl=http://download.opensuse.org/repositories/home:/Bumblebee-Project:/Bumblebee3/SLE_12/\n"`
                        `"enabled=1\n"`
                        `"gpgcheck=0\n" \
                    | $SUDO tee $bumblebee_repo
        fi
    fi
}

function check_repo_RHEL() {
    
    local repolist=$($SUDO yum repolist)
    if [[ $(echo $repolist | awk "/$unregistered/ && ! /$ID-install-media/") ]] ; then
        echo -e "Something went wrong and the install media repository was not set up successfully.\nTry running the script with root priviledges. " >&2
    fi
    if [[ $(echo $repolist | grep -v epel) ]]; then 
        echo -e "Something went wrong and the EPEL repository was not set up successfully.\nCheck your internet connection and try again." >&2
    else
        echo -e "The required repositories have been set up.\nPlease run amdgpu-pro-install to install the amdgpu-pro driver."
        echo "$message"
    fi
}

function check_repo_SUSE() {
    
    local repolist=$($SUDO zypper lr)
    if [[ $(SUSEConnect -s | grep "Not Registered") ]] && [[ $(echo $repolist | grep -v "$ID-install-media") ]]; then
        echo -e "Something went wrong and the install media repository was not set up successfully.\nTry running the script with root priviledges. " >&2
    fi
    if [[ $(echo $repolist | grep -v "Bumblebee-Project") ]]; then
        echo -e "Something went wrong and the Bumblebee repository for DKMS was not set up successfully.\nCheck your internet connection and try again." >&2
    else
        echo -e "The required repositories have been set up.\nPlease run amdgpu-pro-install to install the amdgpu-pro driver."
        echo "$message"
    fi    
}

function dnf_repo() {
	
    local repo=installmedia

	if [ "$name" == "SUSE" ]; then
		echo "/etc/zypp/repos.d/$repo.repo"
	else
		echo "/etc/yum.repos.d/$repo.repo"
	fi
}

function os_release() {
	
	if [[ -r /etc/os-release ]]; then
		. /etc/os-release

		case "$ID" in
		
		rhel|centos|fedora )
            name="RHEL"
            extra="Extra Packages for Linux (EPEL) Repository"
			;;
		sles|sled|opensuse)
			name="SUSE"
            extra="Bumblebee Repository for DKMS"
            ;;
		*)
			echo "Unsupported RedHat derivative OS" >&2
			exit 1
			;;
		esac

	elif [[ -f /etc/redhat-release ]]; then
        if [[ -f /etc/centos-release ]]; then
            ID="centos"
        else
            ID="rhel"
        fi
		name="RHEL"
        extra="Extra Packages for Linux (EPEL) Repository"
	else
		echo "Unsupported OS" >&2
		exit 1
	fi
}
SUDO=$([[ $(id -u) -ne 0 ]] && echo "sudo" ||:)

checkonly=false
err=false

os_release



while (($#))
do
	case "$1" in
	-h|--help)
		usage
		exit 0
		;;
	--check)
		checkonly=true
		shift
		;;
	*)
		ARGS+="$1 "
		shift
		;;
	esac 
done
set -- $ARGS 

if $checkonly ; then
	cat <<END_USAGE
The amdgpu-pro driver requires access to specific RPMs from $ID installation 
media as well as access to $extra

Checking if the prerequisite files and repositories are available in order to 
successfully install the amdgpu-pro driver. 
No changes will be made to the system.

END_USAGE
	
else
    cat <<END_USAGE
The amdgpu-pro driver requires access to specific RPMs from $ID installation 
media as well as access to $extra

This script will confirm that all required prerequisite files and repositories
are available in order to successfully install the amdgpu-pro driver.  
Press ENTER to continue . . ."
END_USAGE
    
    read
fi


install_extrapkgs_$name

install_from_media_$name

if $checkonly; then
	
	if $err; then
		echo -e "WARNING: All prerequisite repositories have not been set up.\n\t Please rerun the script without --check to set up required repositories." >&2
	else 
		echo -e "The required repositories have been set up.\nPlease run amdgpu-pro-install to install the amdgpu-pro driver."
	fi
	echo "No changes were made to the system."
	exit 0
fi

echo "Checking if repositories were set up successfully..."

check_repo_$name



