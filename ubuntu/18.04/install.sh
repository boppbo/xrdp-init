#!/bin/bash

#
# This script is for Ubuntu 18.04 Bionic Beaver to download and install XRDP+XORGXRDP via
# source.
#
# Major thanks to: http://c-nergy.be/blog/?p=11336 for the tips.
#

###############################################################################
# Update our machine to the latest code if we need to.
#

if [ ! $(id -u) ] ; then
    echo 'This script must be run with root privileges' >&2
    exit 1
fi

apt update && apt upgrade -y

if [ -f /var/run/reboot-required ]; then
    echo "A reboot is required in order to proceed with the install." >&2
    echo "Please reboot and re-run this script to finish the install." >&2
    exit 1
fi

###############################################################################
# XRDP
#

# Install the xrdp service so we have the auto start behavior
apt install -y xrdp

systemctl stop xrdp
systemctl stop xrdp-sesman

# Configure the installed XRDP ini files.
# use vsock transport.
sed -i_orig -e 's/use_vsock=false/use_vsock=true/g' /etc/xrdp/xrdp.ini
# use rdp security.
sed -i_orig -e 's/security_layer=negotiate/security_layer=rdp/g' /etc/xrdp/xrdp.ini
# remove encryption validation.
sed -i_orig -e 's/crypt_level=high/crypt_level=none/g' /etc/xrdp/xrdp.ini
# disable bitmap compression since its local its much faster
sed -i_orig -e 's/bitmap_compression=true/bitmap_compression=false/g' /etc/xrdp/xrdp.ini

# use the default lightdm x display
#  sed -i_orig -e 's/X11DisplayOffset=10/X11DisplayOffset=0/g' /etc/xrdp/sesman.ini

# rename the redirected drives to 'shared-drives'
sed -i_orig -e 's/FuseMountName=thinclient_drives/FuseMountName=shared-drives/g' /etc/xrdp/sesman.ini

# Changed the allowed_users
sed -i_orig -e 's/allowed_users=console/allowed_users=anybody/g' /etc/X11/Xwrapper.config

# Enable the hv_sock module
rmmod vmw_vsock_vmci_transport
rmmod vsock
modprobe hv_sock

# Blacklist the vmw module
if [ ! -e /etc/modprobe.d/blacklist_vmw_vsock_vmci_transport.conf ] ; then
cat >> /etc/modprobe.d/blacklist_vmw_vsock_vmci_transport.conf <<EOF
blacklist vmw_vsock_vmci_transport"
EOF
fi


#Ensure hv_sock gets loaded
if [ ! -e /etc/modules-load.d/hv_sock.conf ] ; then
echo "hv_sock" > /etc/modules-load.d/hv_sock.conf
fi

# Configure the policy xrdp session
cat >/etc/polkit-1/localauthority.conf.d/02-allow-colord.conf <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.color-manager.create-device" ||
         action.id == "org.freedesktop.color-manager.modify-profile" ||
         action.id == "org.freedesktop.color-manager.delete-device" ||
         action.id == "org.freedesktop.color-manager.create-profile" ||
         action.id == "org.freedesktop.color-manager.modify-profile" ||
         action.id == "org.freedesktop.color-manager.delete-profile") &&
        subject.isInGroup("{group}"))
    {
        return polkit.Result.YES;
    }
});
EOF

# reconfigure the service
systemctl daemon-reload
systemctl start xrdp

#
# End XRDP
###############################################################################

# Install Gmone Tweak
apt-get install gnome-tweak-tool -y

echo "Install is complete."
echo "Reboot your machine to begin using XRDP."
