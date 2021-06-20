# Raspberry Pi Read Only (RPi-RO)
Simple script to put Raspberry Pi OS Lite to readonly mode and heavily reduce the chance of SD card failure. All read-write files are moved to `/tmp` which is stored in RAM. There are two short macros which you can use to switch between read-only and read-write filesystem.

**Note that this only works for Raspberry Pi OS Lite**.

## Usage
```
# wget https://raw.githubusercontent.com/dominikberse/rpi-read-only/main/rpi-read-only.sh
# sudo ./rpi-read-only.sh
```

## Fine tuning
The problem here is that many applications running on the Raspberry Pi require read-write filesystem access. So whenever you install new applications or services, it might be neccessary to move their temporary files (usually log files) and folders to `/tmp`. This can usually be done easily be creating an appropriate hard link.

To create any required files/folders in `/tmp` at startup, list them inside the `~/.tmpfiles.conf` configuration file.

TODO: Detailled instructions
