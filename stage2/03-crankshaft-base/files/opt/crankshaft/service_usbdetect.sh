#!/bin/bash

source /opt/crankshaft/crankshaft_default_env.sh
source /opt/crankshaft/crankshaft_system_env.sh

CSSTORAGE_DETECTED=0

for _device in /sys/block/sd*/device; do
    if echo $(readlink -f "$_device")|egrep -q "usb"; then
        _disk=$(echo "$_device" | cut -f4 -d/)
        DEVICE="/dev/${_disk}1"
        PARTITION="${_disk}1"
        LABEL=$(blkid /dev/${PARTITION} | sed 's/.*LABEL="//' | cut -d'"' -f1 | sed 's/ //g')
        FSTYPE=$(blkid /dev/${PARTITION} | sed 's/.*TYPE="//' | cut -d'"' -f1)
        if [ $LABEL == "CSSTORAGE" ]; then
            log_echo "CSSTORAGE detected"
            echo "" > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] External CS-USB-Storage detected - mounting..." > /dev/tty3
            echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
            if [ $FSTYPE == "fat" ] || [ $FSTYPE == "vfat" ] || [ $FSTYPE == "ext3" ] || [ $FSTYPE == "ext4" ]; then
                /usr/local/bin/crankshaft filesystem system unlock
                mkdir -p /media/${LABEL}
                mount -t auto ${DEVICE} /media/${LABEL} -o rw,umask=0000,async,user
                if [ $? -eq 0 ]; then
                    log_echo "CSSTORAGE - mount successful"
                    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                    echo "[${CYAN}${BOLD} INFO ${RESET}] CSSTORAGE mounted." > /dev/tty3
                    echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3

                    # dashcam related
                    mkdir -p /media/${LABEL}/RPIDC/AUTOSAVE > /dev/null 2>&1
                    mkdir -p /media/${LABEL}/RPIDC/EVENTS > /dev/null 2>&1
                    # kodi related
                    mkdir -p /media/${LABEL}/KODI > /dev/null 2>&1
                    rm -rf /home/pi/.kodi > /dev/null 2>&1
                    ln -s /media/${LABEL}/KODI /home/pi/.kodi
                    chmod 777 /home/pi/.kodi > /dev/null 2>&1
                    # Allow all users rw to CSSTORAGE and subfolders/files
                    chmod -R 777 /media/${LABEL} > /dev/null 2>&1
                    chmown -R pi:pi /home/pi/.kodi > /dev/null 2>&1
                    /usr/local/bin/crankshaft filesystem system lock
                    CSSTORAGE_DETECTED=1
                else
                    log_echo "CSSTORAGE - mount failed - running fsck"
                    echo "[${RED}${BOLD} FAIL ${RESET}] *******************************************************" > /dev/tty3
                    echo "[${RED}${BOLD} FAIL ${RESET}] CSSTORAGE mount failed! - Running fsck..." > /dev/tty3
                    echo "[${RED}${BOLD} FAIL ${RESET}] *******************************************************" > /dev/tty3
                    ##############################################################
                    # check fs cause mount failed
                    if [ $FSTYPE == "fat" ] || [ $FSTYPE == "vfat" ]; then
                        umount ${DEVICE} > /dev/null 2>&1
                        show_clear_screen
                        show_cursor
                        echo "${RESET}" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] Checking $DEVICE for errors and repair..." > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        dosfsck -y $DEVICE > /dev/tty3
                        sync
                        sleep 5
                        reboot
                    fi
                    if [ $FSTYPE == "ext3" ] || [ $FSTYPE == "ext4" ]; then
                        umount ${DEVICE} > /dev/null 2>&1
                        show_clear_screen
                        show_cursor
                        echo "${RESET}" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] Checking $DEVICE for errors and repair..." > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        fsck.$FSTYPE -f -y $DEVICE > /dev/tty3
                        sync
                        sleep 5
                        reboot
                    fi
                    ##############################################################
                fi
            fi
            continue
        fi

        if [ $SKIP_USB_DETECT -ne 1 ]; then
            if [ $FSTYPE == "fat" ] || [ $FSTYPE == "vfat" ] || [ $FSTYPE == "ext3" ] || [ $FSTYPE == "ext4" ]; then
                umount /tmp/${PARTITION} > /dev/null 2>&1
                mkdir /tmp/${PARTITION} > /dev/null 2>&1
                mount -t auto ${DEVICE} /tmp/${PARTITION}
                if [ $? -ne 0 ]; then
                    ##############################################################
                    # check fs cause mount failed
                    if [ $FSTYPE == "fat" ] || [ $FSTYPE == "vfat" ]; then
                        umount ${DEVICE} > /dev/null 2>&1
                        show_clear_screen
                        show_cursor
                        echo "${RESET}" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] Checking $DEVICE for errors and repair..." > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        dosfsck -y $DEVICE > /dev/tty3
                        sync
                        sleep 5
                        reboot
                    fi
                    if [ $FSTYPE == "ext3" ] || [ $FSTYPE == "ext4" ]; then
                        show_clear_screen
                        show_cursor
                        echo "${RESET}" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] Checking $DEVICE for errors and repair..." > /dev/tty3
                        echo "[${RED}${BOLD} WARN ${RESET}] *******************************************************" > /dev/tty3
                        fsck.$FSTYPE -f -y $DEVICE > /dev/tty3
                        sync
                        sleep 5
                        reboot
                    fi
                    ##############################################################
                else
                    USB_DEBUGMODE=$(ls /tmp/${PARTITION} | grep ENABLE_DEBUG | head -1)
                    if [ ! -z ${USB_DEBUGMODE} ]; then
                        log_echo "${DEVICE} - Debug trigger file detected"
                        show_clear_screen
                        echo "" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] Debug Mode trigger file detected on ${DEVICE} (${LABEL})" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] Starting in debug mode...${RESET}" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                        touch /tmp/usb_debug_mode
                    fi
                    USB_DEVMODE=$(ls /tmp/${PARTITION} | grep ENABLE_DEVMODE | head -1)
                    if [ ! -z ${USB_DEVMODE} ] && [ ${DEV_MODE} -ne 1 ] && [ -z ${USB_DEBUGMODE} ]; then
                        log_echo "${DEVICE} - Dev Mode trigger file detected"
                        show_clear_screen
                        echo "" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] Dev Mode trigger file detected on ${DEVICE} (${LABEL})" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] Starting in dev mode...${RESET}" > /dev/tty3
                        echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                        touch /tmp/usb_dev_mode
                    fi
                    if [ $ALLOW_USB_FLASH -eq 1 ]; then
                        UPDATEZIP=$(ls -Art /tmp/${PARTITION} | grep crankshaft-ng | grep .zip | grep -v md5 | grep -v ^._ | tail -1)
                        FLAG=0
                        if [ ! -z ${UPDATEZIP} ]; then
                            UNPACKED=$(unzip -l /tmp/${PARTITION}/${UPDATEZIP} | grep crankshaft-ng | grep .img | grep -v md5 | grep -v ^._ | awk {'print $4'})
                            if [ ! -f /tmp/${PARTITION}/${UNPACKED} ]; then
                                show_clear_screen
                                echo "" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] Update zip found on ${DEVICE} (${LABEL})" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] Unpacking file $UNPACKED" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] Please wait..." > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                                show_cursor
                                rm /tmp/${PARTITION}/*.md5 > /dev/null 2>&1
                                rm /tmp/${PARTITION}/*.img > /dev/null 2>&1
                                unzip -q -o /tmp/${PARTITION}/${UPDATEZIP} -d /tmp/${PARTITION}
                                hide_cursor
                                FLAG=1
                            fi
                        fi
                        UPDATEFILE=$(ls -Art /tmp/${PARTITION} | grep crankshaft-ng | grep .img | grep -v md5 | grep -v ^._ | tail -1)
                        if [ ! -z ${UPDATEFILE} ]; then
                            if [ ${FLAG} -ne 1 ]; then
                                show_clear_screen
                            else
                                show_screen
                            fi
                            echo "" > /dev/tty3
                            echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                            echo "[${CYAN}${BOLD} INFO ${RESET}] Update file found on ${DEVICE} (${LABEL})" > /dev/tty3
                            echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                            if [ -f /etc/crankshaft.build ] && [ -f /etc/crankshaft.date ]; then
                                CURRENT="$(cat /etc/crankshaft.date)-$(cat /etc/crankshaft.build)"
                            else
                                CURRENT=""
                            fi
                            NEW=$(basename ${UPDATEFILE} | cut -d- -f1-3,6 | cut -d. -f1) # use date and hash
                            FORCEFLASH=$(ls /tmp/${PARTITION} | grep FORCE_FLASH | head -1)
                            if [ "$CURRENT" == "$NEW" ] && [ -z $FORCEFLASH ]; then
                                echo "[${CYAN}${BOLD} INFO ${RESET}] IMAGE already flashed - ignoring." > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                                umount /tmp/${PARTITION} > /dev/tty3
                                rmdir /tmp/${PARTITION} > /dev/tty3
                                continue
                            fi
                            echo "[${CYAN}${BOLD} INFO ${RESET}] Checking file ${UPDATEFILE}${RESET}" > /dev/tty3
                            echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                            echo "[${CYAN}${BOLD} INFO ${RESET}] Please wait..." > /dev/tty3
                            echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                            show_cursor

                            if [ -f /tmp/${PARTITION}/${UPDATEFILE} ]; then
                                SIZE=$(($(wc -c < "/tmp/${PARTITION}/${UPDATEFILE}") / 1024 / 1024 / 1014))
                            else
                                echo "" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}] *******************************************************" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}] Image check has failed - abort.${RESET}" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}] *******************************************************" > /dev/tty3
                                umount /tmp/${PARTITION} > /dev/tty3
                                rmdir /tmp/${PARTITION} > /dev/tty3
                                continue
                            fi
                            cd /tmp/${PARTITION}
                            MD5SUM=$(md5sum -c ${UPDATEFILE}.md5 | grep OK | cut -d: -f2)
                            if [ ! -z ${MD5SUM} ]; then
                                echo "${RESET}" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] Image is consistent -> Preparing flash mode...${RESET}" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}]" > /dev/tty3
                                echo "[${CYAN}${BOLD} INFO ${RESET}] *******************************************************" > /dev/tty3
                                # mount /boot rw to init flash mode
                                mount -o remount,rw /boot
                                mkinitramfs -o /boot/initrd.img > /dev/null 2>&1
                                # cleanup
                                sed -i 's/^initramfs initrd.img followkernel//' /boot/config.txt
                                sed -i 's/^ramfsfile=initrd.img//' /boot/config.txt
                                sed -i 's/^ramfsaddr=-1//' /boot/config.txt
                                sed -i '/./,/^$/!d' /boot/config.txt
                                sed -i 's/rootdelay=10//' /boot/cmdline.txt
                                sed -i 's/initrd=-1//' /boot/cmdline.txt
                                # Set entries
                                echo "initramfs initrd.img followkernel" >> /boot/config.txt
                                echo "ramfsfile=initrd.img" >> /boot/config.txt
                                echo "ramfsaddr=-1" >> /boot/config.txt
                                sed -i 's/splash //' /boot/cmdline.txt
                                sed -i 's/vt.global_cursor_default=0 //' /boot/cmdline.txt
                                sed -i 's/plymouth.ignore-serial-consoles //' /boot/cmdline.txt
                                sed -i 's/$/ rootdelay=10/' /boot/cmdline.txt
                                sed -i 's/$/ initrd=-1/' /boot/cmdline.txt
                                # remove possible existing force trigger to prevent flash loop
                                rm /tmp/${PARTITION}/FORCE_FLASH > /dev/null 2>&1
                                echo "${RESET}" > /dev/tty3
                                echo "[${GREEN}${BOLD} EXEC ${RESET}] *******************************************************" > /dev/tty3
                                echo "[${GREEN}${BOLD} EXEC ${RESET}]" > /dev/tty3
                                echo "[${GREEN}${BOLD} EXEC ${RESET}] System is ready for flashing - reboot...${RESET}" > /dev/tty3
                                echo "[${GREEN}${BOLD} EXEC ${RESET}]" > /dev/tty3
                                echo "[${GREEN}${BOLD} EXEC ${RESET}] *******************************************************" > /dev/tty3
                                sleep 5
                                reboot
                            else
                                echo "${RESET}" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}] *******************************************************" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}]" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}] Image check has failed - abort.${RESET}" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}]" > /dev/tty3
                                echo "[${RED}${BOLD} FAIL ${RESET}] *******************************************************" > /dev/tty3
                                umount /tmp/${PARTITION} > /dev/tty3
                                rmdir /tmp/${PARTITION} > /dev/tty3
                                continue
                            fi
                        fi
                    fi
                fi
                umount /tmp/${PARTITION} > /dev/tty3
                rmdir /tmp/${PARTITION} > /dev/tty3
            fi
        fi
    fi
done

# No external storage available - remove lost local folders / files
if [ $CSSTORAGE_DETECTED -eq 0 ]; then
    /usr/local/bin/crankshaft filesystem system unlock
    rm -rf /media/CSSTORAGE > /dev/null 2>&1
    rm -rf /home/pi/.kodi > /dev/null 2>&1
    /usr/local/bin/crankshaft filesystem system lock
fi

exit 0
