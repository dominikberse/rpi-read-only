#!/bin/bash
set -e

# root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Quitting." 
   exit 1
fi

# disclaimer
printf "\n\n##########\n"
printf "WARNING: This may break your system!\n"
printf "This script is intended to be used on a fresh installation.\n"
printf "Backup any relevant data before executing this script.\n"
printf "##########\n\n\n"

printf "Are you sure you want to continue? [yes|No]\n"
read confirm
case $confirm in
    yes ) ;;
    * ) echo "Please type [yes] in order to continue. Quitting." ; exit 1;;
esac

# update system
printf "\n\n##########\n"
printf "Updating sources...\n\n"
apt-get update -y

# upgrade system if neccessary
printf "\n\n##########\n"
printf "Upgrade system before going read-only? [y|n]\n"
read yn
case $yn in
    [Yy]* ) apt-get upgrade -y ; break;;
    [Nn]* ) break;;
    * ) echo "Invalid answer. Quitting." ; exit 1;;
esac

# change logger
printf "\n\n##########\n"
printf "Installing in-memory logger...\n\n"
apt-get install -y busybox-syslogd
apt-get remove -y --purge rsyslog

# remove unnecessary
printf "\n\n##########\n"
printf "Cleaning up...\n\n"
apt-get remove -y --purge triggerhappy logrotate dphys-swapfile
apt-get autoremove -y --purge

# edit /boot/cmdline.txt
printf "\n\n##########\n"
printf "Updating /boot/config.txt\n\n"
sed -i '$s/$/ fastboot noswap ro/' /boot/cmdline.txt

# set mountpoints
printf "\n\n##########"
printf "Adjusting /etc/fstab ..."
echo "tmpfs        /tmp            tmpfs   nosuid,nodev,mode=1777         0       0" >> /etc/fstab
echo "tmpfs        /var/spool        tmpfs   nosuid,nodev         0       0" >> /etc/fstab
echo "tmpfs        /var/log        tmpfs   nosuid,nodev         0       0" >> /etc/fstab
echo "tmpfs        /var/tmp        tmpfs   nosuid,nodev         0       0" >> /etc/fstab
sed -i '/^PARTUUID/ s/defaults/defaults,ro/' /etc/fstab

# move to temporary file system
printf "\n\n##########\n"
printf "Moving r/w files to /tmp ...\n\n"
rm -rf /var/lib/dhcp /var/lib/dhcpcd5 /var/run/wpa_supplicant /etc/resolv.conf
ln -s /tmp/dhcp /var/lib/dhcp
ln -s /tmp/dhcpcd5 /var/lib/dhcpcd5
ln -s /tmp/wpa_supplicant /var/run/wpa_supplicant
touch /tmp/dhcpcd.resolv.conf
ln -s /tmp/dhcpcd.resolv.conf /etc/resolv.conf

# adjust random-seed
rm /var/lib/systemd/random-seed
ln -s /tmp/random-seed /var/lib/systemd/random-seed
sed -i '/^\[Service\]/a\ExecStartPre=\/bin\/echo "" > \/tmp\/random-seed' /lib/systemd/system/systemd-random-seed.service

# configure tmpfiles.d
printf "\n\n##########\n"
printf "Adding tmpfiles.d configuration...\n\n"
tee /etc/tmpfiles.d/tmpfiles.conf > /dev/null <<'EOF'
# list required directories

d /tmp/random-seed 0755 - - -
d /tmp/dhcp 0755 - - -
d /tmp/dhcpcd5 0755 - - -
d /tmp/wpa_supplicant 0755 - - -

d /var/log/nginx 0755 - - -
d /var/log/mosquitto 0755 mosquitto mosquitto - -
EOF

# create link to local user directory
ln -s /etc/tmpfiles.d/tmpfiles.conf /home/pi/.tmpfiles.conf

# provide shortcuts
printf "\n\n##########\n"
printf "Generating rw/ro shortcuts...\n\n"
tee -a /etc/bash.bashrc > /dev/null <<'EOF'

set_bash_prompt() {
    fs_mode=$(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p")
    PS1='\[\033[01;32m\]\u@\h${fs_mode:+($fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
}

alias ro='sudo mount -o remount,ro / ; sudo mount -o remount,ro /boot'
alias rw='sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot'

PROMPT_COMMAND=set_bash_prompt
EOF

# create initialization script
printf "\n\n##########\n"
printf "Generating user-init script...\n\n"
tee /home/pi/.init-readonly-fs.sh > /dev/null <<'EOF'
#!/bin/bash

# this script is executed upon system startup (as root)
# copy files to an appropriate folder inside /tmp to allow r/w access
# changes to these files will be lost once the system is restarted

# e.g. copy klipper_config directory
#cp -rp /home/pi/klipper_config /tmp/klipper_config
EOF

chown pi /home/pi/.init-readonly-fs.sh
chmod +x /home/pi/.init-readonly-fs.sh

# run initialization on startup
printf "\n\n##########\n"
printf "Generating user-init service...\n\n"
tee /etc/systemd/system/init-readonly-fs.service > /dev/null <<'EOF'
[Unit]
After = network-online.target
Wants = network-online.target

[Service]
Type = oneshot
RemainAfterExit = yes
ExecStart = /home/pi/.init-readonly-fs.sh

[Install]
WantedBy = multi-user.target
EOF

systemctl daemon-reload
systemctl enable init-readonly-fs.service

# all done
printf "\n\n##########\n"
echo "Rebooting... cross your fingers [ENTER].\n"
read
reboot
