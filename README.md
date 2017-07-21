# amdgpu-pro-preinstall
A preinstall script for installing amdgpu-pro drivers. Compatible with RedHat, CentOS and SUSE Enterprise Linux Operating Systems

Download the latest amdgpu-pro drivers here:
  
   http://support.amd.com/en-us/kb-articles/Pages/AMDGPU-PRO-Driver-for-Linux-Release-Notes.aspx

The AMDGPU-Pro driver requires access to specific RPMs from installation media as well as Extra Packages for Enterprise Linux (EPEL) for purposes of dependency resolution.  amdgpu-pro-preinstall will confirm that all required prerequisite files and repositories are available in order to successfully install the AMDGPU-Pro driver in the Red Hat and SLES environment.  It can be run as follows:

    sh amdgpu-pro-preinstall.sh --check
  
This will check if the required repositories are available to ensure a smooth installation. If there are any warnings, the script can be executed again without any options to build the necessary repositories

    sh amdgpu-pro-preinstall.sh

Note that an internet connection will be required if EPEL is not found and RHEL/SLES installation media from a DVD, USB key or a mounted ISO will be required if the system does not have an active RHEL/SLES Subscription.

