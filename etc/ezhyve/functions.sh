fbsdfetch() {
	if [ ! -d $PATH_FBSDDISTFILES/$EZHYVE_OS_VERSION ]; then
		/bin/mkdir -p $PATH_FBSDDISTFILES/$EZHYVE_OS_VERSION;
	fi

        for i in $FBSD_DISTFILES; do
                if [ ! -e $PATH_FBSDDISTFILES/$EZHYVE_OS_VERSION/$i ]; then
                        echo "fetching distfile $i";
                        /usr/bin/fetch -q $FBSD_MIRROR/pub/FreeBSD/releases/amd64/amd64/$EZHYVE_OS_VERSION/$i -o $PATH_FBSDDISTFILES/$EZHYVE_OS_VERSION 2>/dev/null ||
                        /usr/bin/fetch -q $FBSD_MIRROR/pub/FreeBSD/snapshots/amd64/amd64/$EZHYVE_OS_VERSION/$i -o $PATH_FBSDDISTFILES/$EZHYVE_OS_VERSION 2>/dev/null ||
			perror "error fetching distfile $i for $EZHYVE_OS_VERSION"
                fi      
        done
}

createimage() {
        if [ -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "$EZHYVE_VM_NAME already loaded"
        fi      
        
        if [ ! -d $PATH_BHYVEVMS/$EZHYVE_VM_NAME ]; then
                /bin/mkdir -p $PATH_BHYVEVMS/$EZHYVE_VM_NAME;
        fi      
        
        if [ ! -e "$EZHYVE_IMAGEPATH" ]; then
                echo "creating image $EZHYVE_VM_NAME";
                /usr/bin/truncate -s $EZHYVE_DISKSIZE "$EZHYVE_IMAGEPATH" ||
		perror "error creating image file $EZHYVE_IMAGEPATH"
        fi      
}

fbsdformatimage() {
	if [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		perror "not supported for non FreeBSD guests"
	fi

	if [ -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "fbsdformatimage: VM loaded."
	fi

	if [ ! -e $PATH_BHYVEVMS/$EZHYVE_VM_NAME ]; then
		perror "did you run $scriptname create vmname first?"
	fi

	# if we got an image to this
	if [ -e $EZHYVE_IMAGEPATH ]; then
                # check if filetype ! data
                if [ `/usr/bin/file -s $EZHYVE_IMAGEPATH|/usr/bin/awk '{print $2}'` = "data" ];then
                        echo "image propably empty";
                        echo "formating image";
			if [ "$EZHYVE_DEVTYPE" = "raw" ]; then
				EZHYVE_VMDEV=$( mdconfig -af "$EZHYVE_IMAGEPATH" )
				# mdconfig -lv
			fi
                else
			perror "beware, image doesnt seem empty $EZHYVE_IMAGEPATH"
                fi
	fi

	if [ ! -c "/dev/$EZHYVE_VMDEV" ]; then
		perror "fbsdformatimage didnt create $EZHYVE_VMDEV"
	fi
	
	# otherwise assume a EZHYVE_VMDEV was specified
	# TODO: this produces #gpart: arg0 'md1': Invalid argument
	if [ ! "$EZHYVE_VMDEV" = "" ]; then
		echo "gpart destroy -F $EZHYVE_VMDEV"
		gpart destroy -F "/dev/$EZHYVE_VMDEV"
		dd if=/dev/zero of="/dev/$EZHYVE_VMDEV" bs=512 count=1
	fi
	
	if [ "$EZHYVE_LAYOUT" = "mbr" ]; then
		fdisk -BI "$EZHYVE_VMDEV"
		bsdlabel -wB "${EZHYVE_VMDEV}s1"
		newfs -U "${VMDEV}s1a"
	elif [ "$EZHYVE_LAYOUT" = "gpt" ]; then
		echo "gpart create -s gpt $EZHYVE_VMDEV"
		gpart create -s gpt "$EZHYVE_VMDEV"
		echo "gpart add -t freebsd-boot -s 256k $EZHYVE_VMDEV"
		gpart add -t freebsd-boot -s 256k $EZHYVE_VMDEV
		echo "gpart bootcode -b /boot/mbr -p /boot/gptboot -i 1 $EZHYVE_VMDEV"
		gpart bootcode -b /boot/mbr -p /boot/gptboot -i 1 "$EZHYVE_VMDEV"
		echo "gpart add -t freebsd-ufs $EZHYVE_VMDEV"
		gpart add -t freebsd-ufs "$EZHYVE_VMDEV"
		echo "gpart show $EZHYVE_VMDEV"
		gpart show "$EZHYVE_VMDEV"
		echo "newfs -U ${EZHYVE_VMDEV}p2"
		newfs -U "${EZHYVE_VMDEV}p2"
	else
		perror "$EZHYVE_LAYOUT unspecified";
	fi

	# destroy the device
	[ "$EZHYVE_DEVTYPE" = "raw" ] && mdconfig -du $EZHYVE_VMDEV
}

fbsdprovision() {
	if [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		perror "function not supported on $EZHYVE_VM_TYPE"
	fi

	if [ -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "vm $EZHYVE_VM_NAME is loaded";
	fi

	if [ ! -d $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt ]; then
		mkdir $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt;
	fi
	
	if [ "$EZHYVE_DEVTYPE" = "raw" ]; then
		if [ ! -e "$EZHYVE_IMAGEPATH" ]; then
			perror "$EZHYVE_IMAGEPATH does not exit."
		fi
	elif [ ! -e "/dev/$EZHYVE_VMDEV" ]; then
		perror "$EZHYVE_VMDEV does not exist."
	fi

	if [ -e "$EZHYVE_IMAGEPATH" ] && [ "$EZHYVE_DEVTYPE" = "raw" ] ; then
		EZHYVE_VMDEV=$( mdconfig -af "$EZHYVE_IMAGEPATH" )
		if [ "$EZHYVE_LAYOUT" = "mbr" ]; then
			mount "/dev/${EZHYVE_VMDEV}s1a" $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt || perror "error mounting ${EZHYVE_VMDEV}s1a on $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt"
		elif [ "$EZHYVE_LAYOUT" = "gpt" ]; then
			mount "/dev/${EZHYVE_VMDEV}p2" $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt || perror "error mounting ${EZHYVE_VMDEV}p2 on $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt"
		fi
	elif [ "$EZHYVE_DEVTYPE" = "" ] ; then
                if [ "$EZHYVE_LAYOUT" = "mbr" ]; then
                        mount "/dev/${EZHYVE_VMDEV}s1a" $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt || perror "error mounting ${EZHYVE_VMDEV}s1a on $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt"
                elif [ "$EZHYVE_LAYOUT" = "gpt" ]; then
                        mount "/dev/${EZHYVE_VMDEV}p2" $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt || perror "error mounting ${EZHYVE_VMDEV}p2 on $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt"
                fi

	fi

	if [ -e "$PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt/root" ]; then
		perror "appears to be populated";
	fi
	
	#sysctl -w vfs.hirunningspace=16777216
	sysctl -w vfs.hirunningspace=50331648
	#sysctl -w vfs.hirunningspace=67108864
	# we need to somehome improve the speed of this
	# 10 minutes for base.txz + kernel.txz with 16777216 also for 50331648 ...
	for i in $FBSD_DISTFILES; do
		cat "$PATH_FBSDDISTFILES/$EZHYVE_OS_VERSION/$i" | tar xpf - -C $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt
	done

	if [ -d "$PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt/boot/kernel" ]; then
		if [ "$EZHYVE_DEVLAYOUT" = "mbr" ]; then
			BOOTDEV=ada0s1a
			# TODO: vtb0s1a for VirtIO
		else
			BOOTDEV=ada0p2
			# TODO: vtbd0p2 for VirtIO
		fi

# TODO: make this configurable by sourcing or calling a script ...
		cat > "$PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt/etc/fstab" <<-EOF
# Device        Mountpoint      FStype  Options Dump    Pass#
/dev/$BOOTDEV   /               ufs     rw      1       1
EOF

# TODO: can we define specific ips?
		cat > "$PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt/etc/rc.conf" <<-EOF
hostname="$EZHYVE_VM_NAME"

ifconfig_vtnet0="DHCP"
sshd_enable="YES"

sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
EOF

		cat > "$PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt/etc/ttys" <<-EOF
console "/usr/libexec/getty std.9600" vt100 on secure
EOF

	echo "$FBSD_TIMEZONE" >> "$PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt/var/db/zoneinfo"
	tzsetup -r -C $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt

	echo "PermitRootLogin yes" >> "$PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt/etc/ssh/sshd_config"

	umount $PATH_BHYVEVMS/$EZHYVE_VM_NAME/mnt || perror "error umounting";
		
	fi
		
	# destroy the device
	[ "$EZHYVE_DEVTYPE" = "raw" ] && mdconfig -du $EZHYVE_VMDEV
}

ezhyve_fetch() {
	# $1 = $ISOSITE
	# $2 = $ISOIMG
	#ezhyve_checkiso
        if [ ! -d $PATH_ISOFILES ]; then
                /bin/mkdir -p $PATH_ISOFILES || perror "error creating $PATH_ISOFILES";
        fi

	# ezhyve_checkiso $PATH_ISOFILES$2
	if [ -e "$PATH_ISOFILES/$2" ]; then
		perror "iso already in place";
	fi

	/usr/bin/fetch -q $1$2 -o $PATH_ISOFILES/$2 2>/dev/null ||
	perror "error fetching image $1$2";
}

ezhyve_getconfig() {
	# $1 = EZHYVE_VM_NAME
	if [ -e $PATH_VMCONF/$1.conf ]; then
		unset $EZHYVE_VM_TYPE $EZHYVE_OS_VERSION $EZHYVE_RAMSIZE $EZHYVE_DISKSIZE $EZHYVE_CPUNUM $EZHYVE_LAYOUT $EZHYVE_VIRTIO $EZHYVE_VMDEV $EZHYVE_DEVICEMAP $EZHYVE_IMGPATH $EZHYVE_ISOIMGPATH;
		unset $EZHYVE_VMID $EZHYVE_IMAGEPATH $EZHYVE_VMDEV $EZHYVE_DEVTYPE
		unset $ISOSITE $ISOIMG $GRUBBOOTCMD $GRUBISOCMD $HOSTBRIDGE $BHYVEFLAGS $VIRTIO
		# unset $EZHYVE_CONSOLE ... loaded from ezhyve.conf
		. $PATH_VMCONF/$1.conf;
	else 
		perror "Error getting config $PATH_VMCONF/$1.conf";
	fi
		
}

ezhyve_writeconfig() {
	if [ -e $PATH_VMCONF/$EZHYVE_VM_NAME.conf ]; then
		perror "VM config VM already exists. $PATH_VMCONF/$EZHYVE_VM_NAME.conf"
	else
		echo "EZHYVE_VM_TYPE=\"$EZHYVE_VM_TYPE\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_OS_VERSION=\"$EZHYVE_OS_VERSION\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_RAMSIZE=\"$EZHYVE_RAMSIZE\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_DISKSIZE=\"$EZHYVE_DISKSIZE\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_CPUNUM=\"$EZHYVE_CPUNUM\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		# TODO: if wanted you can write per machine EZHYVE_CONSOLE ... does it make sense?
		# if so unset EZHYVE_CONSOLE in ezhyve_getconfig
		#echo "EZHYVE_CONSOLE=\"$EZHYVE_CONSOLE\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_LAYOUT=\"$EZHYVE_LAYOUT\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_VIRTIO=\"$EZHYVE_VIRTIO\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_DEVICEMAP=\"$EZHYVE_DEVICEMAP\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_ISOIMGPATH=\"$EZHYVE_ISOIMGPATH\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_VMID=\"$EZHYVE_VMID\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_IMAGEPATH=\"$EZHYVE_IMAGEPATH\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_VMDEV=\"$EZHYVE_VMDEV\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		echo "EZHYVE_DEVTYPE=\"$EZHYVE_DEVTYPE\"" >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		if [ -e "$PATH_VMTEMPLATE/$EZHYVE_VM_TYPE/$EZHYVE_OS_VERSION" ]; then
			cat $PATH_VMTEMPLATE/$EZHYVE_VM_TYPE/$EZHYVE_OS_VERSION >> $PATH_VMCONF/$EZHYVE_VM_NAME.conf;
		fi
	fi
}

ezhyve_echovars() {
		echo "EZHYVE_VM_NAME=\"$EZHYVE_VM_NAME\""
		echo "EZHYVE_VM_TYPE=\"$EZHYVE_VM_TYPE\""
                echo "EZHYVE_OS_VERSION=\"$EZHYVE_OS_VERSION\""
                echo "EZHYVE_RAMSIZE=\"$EZHYVE_RAMSIZE\""
                echo "EZHYVE_DISKSIZE=\"$EZHYVE_DISKSIZE\""
                echo "EZHYVE_CPUNUM=\"$EZHYVE_CPUNUM\""
                echo "EZHYVE_CONSOLE=\"$EZHYVE_CONSOLE\""
                echo "EZHYVE_LAYOUT=\"$EZHYVE_LAYOUT\""
                echo "EZHYVE_VIRTIO=\"$EZHYVE_VIRTIO\""
                echo "EZHYVE_DEVICEMAP=\"$EZHYVE_DEVICEMAP\""
                echo "EZHYVE_ISOIMGPATH=\"$EZHYVE_ISOIMGPATH\""
                echo "EZHYVE_VMID=\"$EZHYVE_VMID\""
                echo "EZHYVE_IMAGEPATH=\"$EZHYVE_IMAGEPATH\""
                echo "EZHYVE_VMDEV=\"$EZHYVE_VMDEV\""
                echo "EZHYVE_DEVTYPE=\"$EZHYVE_DEVTYPE\""
		# TODO: add the vars from template
}

ezhyve_gettemplate() {
	# $1 = EZHYVE_VM_TYPE
	# $2 = EZHYVE_OS_VERSION
	if [ !  -e $PATH_VMTEMPLATE/$1 ]; then
		perror "Unknown type -t $1";
	fi

	if [ ! -e $PATH_VMTEMPLATE/$1/$2 ]; then
		perror "Unknown version -v $2";
	elif [ -e $PATH_VMTEMPLATE/$1/$2 ]; then
		unset $DISTSITE $ISOSITE $ISOIMG $GRUBBOOTCMD $GRUBISOCMD $HOSTBRIDGE $BHYVEFLAGS $VIRTIO;
		# TODO: don't reset $DEVLAYOUT (yet?)
		. $PATH_VMTEMPLATE/$1/$2;
	else
		perror "Error loading template $PATH_VMTEMPLATE/$1/$2"	
	fi
}

ezhyve_grubcheck() {
	if [ ! -x /usr/local/sbin/grub-bhyve ]; then
		perror "You need to install sysutils/grub2-bhyve";
	fi
}

ezhyve_screencheck() {
	if [ ! -x /usr/local/bin/screen ]; then
		perror "You need to install sysutils/screen";
	fi
}

ezhyve_tmuxcheck() {
	if [ ! -x /usr/local/bin/tmux ]; then
		perror "You need to install sysutils/tmux";
	fi
}

ezhyve_vmcheck() {
	# TODO: make it usable for cdboot/start ... we dont want to exit here when config and image exist
	# $1 = EZHYVE_VM_NAME
	if [ -e $PATH_VMCONF/$1.conf ]; then
		perror "VM config for $PATH_VMCONF/$1.conf found";
	fi
	if [ -d $PATH_BHYVEDATA/$1 ]; then
		perror "VM dir for $PATH_BHYVEDATA/$1 found".
	fi
}

ezhyve_vmdelete() {
	# $1 = EZHYVE_VM_NAME
	# TODO: make rm interactive? or commandline switch -y?
	if [ ! -e $PATH_VMCONF/$1.conf ] && [ ! -d $PATH_BHYVEDATA/$1 ]; then
		perror "VM config and datadir not found ... nothing to delete!"
	fi

	if [ -e $PATH_VMCONF/$1.conf ]; then
		rm "$PATH_VMCONF/$1.conf";
		echo "deleted config $PATH_VMCONF/$1.conf";
	fi

	if [ -d $PATH_BHYVEVMS/$1 ]; then
		rm -rf "$PATH_BHYVEVMS/$1"
		echo "deleted vm dir $PATH_BHYVEVMS/$1";
	fi
}

ezhyve_checkiso() {
	# $1 = $EZHYVE_ISOIMGPATH
	if [ ! -e "$1" ]; then
		perror "iso image $1 not found";
	fi
}

ezhyve_generatevmid() {
	# this sets EZHYVE_VMID
	# is used for tapX nmdmX
	# this gets the next free VMID (no vm -> VMID=1; VMID 1-6 taken -> VMID=7; VMID 1-6 but 3 not taken -> VMID=3
	x=1
	EZHYVE_VMID=9000
        if [ -e /tmp/ezhyvesillytmpfile ]; then
                rm /tmp/ezhyvesillytmpfile;
        fi

	if [ `ls $PATH_VMCONF/*.conf 2>/dev/null|wc -l` -gt 0 ]; then
       		for i in `grep EZHYVE_VMID $PATH_VMCONF/*.conf|cut -d= -f2|sed -e 's,",,g'`; do
		# TODO: need to fix this ... maybe via array
			echo $i >> /tmp/ezhyvesillytmpfile;
        	done

		# lets check if we have an error in the matrix ... VMID has to be uniq
		if [ `cat /tmp/ezhyvesillytmpfile|uniq|wc -l` -eq `ls $PATH_VMCONF/*.conf|wc -l` ]; then

			for i in `sort -n /tmp/ezhyvesillytmpfile`; do
       		        	if [ $x -eq $i ]; then
       		                 	x=$(($x+1));
       		                 	EZHYVE_VMID=$x;
	                	else
                        		EZHYVE_VMID=$x;
					break;
                		fi
			done
		else
			# TODO: if duplicate replace with new one
			perror "seems like we got a non uniq EZHYVE_VMID somewhere ... grep VMID etc/vmconf/* and eliminate the duplicated VMID for now ";
		fi
	else
        	EZHYVE_VMID=1;
	fi
	if [ -e /tmp/ezhyvesillytmpfile ]; then
		rm /tmp/ezhyvesillytmpfile;
	fi
}

ezhyve_list() {
	# TODO: maybe something with ps?
	# didn't see much in ps yet
	if [ ! -d /dev/vmm ]; then
		perror "list: No VMs running! Exiting."
	else
		ls -1 /dev/vmm/*
	fi
}

ezhyve_attach() {
	# TODO: would it be better to not write it to the per config?
	if [ ! -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "ezhyve_attach: $EZHYVE_VM_NAME failed to load! Exiting."
	fi

	if [ $EZHYVE_CONSOLE = default ]; then
		perror "Something must have gone wrong if you cannot see the VM in the console you launched it on. Exiting"
	elif [ $EZHYVE_CONSOLE = nmdm ]; then
		echo "detach with \" ~. \""
		cu -l /dev/nmdm${EZHYVE_VMID}B -s 9600
	elif [ $EZHYVE_CONSOLE = lpc ]; then
		echo "detach with \" ~. \""
		cu -l /dev/nmdm${EZHYVE_VMID}B -s 9600
	elif [ $EZHYVE_CONSOLE = tmux -o $EZHYVE_CONSOLE = tmux-detached ]; then
		echo "detach with \" CTRL-b d \""
		tmux attach-session -t $EZHYVE_VM_NAME
	else
		perror "EZHYVE_CONSOLE not defined. Exiting."
	fi
}

ezhyve_pretest() {
	if [ ! $( grep -o POPCNT /var/run/dmesg.boot | uniq ) = "POPCNT" ]; then
		perror "Your CPU does not appear to support EPT! Exiting."
	fi

	if [ ! "$( kldstat | grep -o vmm.ko )" = "vmm.ko" ]; then
		echo "vmm.ko kernel module is not loaded. Loading...";
		kldload vmm;
	else
		echo "vmm.ko is loaded."
	fi

	if [ ! "$( ifconfig -l | grep -o bridge0 )" = "bridge0" ]; then
		echo "if_tap, bridgestp and if_bridge kernel modules are not loaded."
		echo "Loading..."
		kldload if_tap
		kldload bridgestp
		kldload if_bridge
		echo "Creating the bridge0 network interface."
		ifconfig bridge0 create
		ifconfig bridge0 up
	fi

	if [ "$EZHYVE_CONSOLE" = "tmux" ]; then
		ezhyve_tmuxcheck;
	fi
}

ezhyve_destroy() {
	if [ ! -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "vmdestroy: $EZHYVE_VM_NAME is not loaded! Exiting."
	else
		echo "vmdestroy: Destroying $EZHYVE_VM_NAME"
		/usr/sbin/bhyvectl --destroy --vm="$EZHYVE_VM_NAME" > /dev/null 2>&1
		echo "$EZHYVE_VM_NAME ungracefully stopped"
		echo "vmdestroy: Destroying tap$EZHYVE_VMID"
		ifconfig tap$EZHYVE_VMID destroy
	fi

	if [ $EZHYVE_CONSOLE = tmux ]; then
		if [ "$( tmux list-sessions | grep -o $EZHYVE_VM_NAME )" = "$VMNAME" ]; then
			perror "vmdestroy: tmux session $EZHYVE_VM_NAME is not running! Exiting."
		else
			echo "vmdestroy: Destroying the associated tmux session"
			tmux kill-session -t $EZHYVE_VM_NAME
		fi
	fi
}

ezhyve_grub() {
	echo "Entering vmgrub()"
	ezhyve_grubcheck
	grub-bhyve -m $EZHYVE_DEVICEMAP -M $EZHYVE_RAMSIZE $EZHYVE_VM_NAME
}

ezhyve_cdbootdevicemap() {
	# TODO: make this less ugly by not using tmpfile
	if [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		if [ -e "$EZHYVE_DEVICEMAP" ]; then
			mv "$EZHYVE_DEVICEMAP" /tmp/${EZHYVE_DEVICEMAP}${EZHYVE_VM_NAME};
			grep hd /tmp/${EZHYVE_DEVICEMAP}${EZHYVE_VM_NAME} > "$EZHYVE_DEVICEMAP";
			echo "(cd0) $EZHYVE_ISOIMGPATH" >> "$EZHYVE_DEVICEMAP";
			rm "/tmp/${EZHYVE_DEVICEMAP}${EZHYVE_VM_NAME}";
		else
			perror "EZHYVE_DEVICEMAP not found $EZHYVE_DEVICEMAP"
		fi
	else
		perror "ezhyve_cdbootdevicemap not supported for FreeBSD"
	fi
}

ezhyve_boot() {
	# TODO: did i miss something or is never tried to boot from EZHYVE_VMDEV (didn't find it in vm0)
	if [ -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "ezhyve_boot: $EZHYVE_VM_NAME is loaded! Exiting."
	fi

	if [ ! $( mount | grep -o $EZHYVE_VM_NAME/mnt ) = $EZHYVE_VM_NAME/mnt ]; then
		perror "ezhyve_boot: $EZHYVE_VM_NAME is currently mounted Exiting."
	fi

	if [ "$EZHYVE_DEVTYPE" = "raw" ] && [ "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		if [ ! -e "$EZHYVE_IMAGEPATH" ]; then
			perror "image $EZHYVE_IMAGEPATH doesnt exsit."
		fi
		# do not set EZHYVE_VMDEV if we only find data
		if [ ! `/usr/bin/file -s $EZHYVE_IMAGEPATH|/usr/bin/awk '{print $2}'` = "data" ];then
			EZHYVE_VMDEV=$( mdconfig -af "$EZHYVE_IMAGEPATH" )
		fi
	fi

	if [ "$EZHYVE_LAYOUT" = "mbr" ] && [ "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		VOLPART="/dev/${EZHYVE_VMDEV}s1a"
	elif [ "$EZHYVE_LAYOUT" = "gpt" ] && [ "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		VOLPART="/dev/${EZHYVE_VMDEV}p2"
	fi

	if [ "$EZHYVE_VM_TYPE" = "FreeBSD" ] && [ ! "$EZHYVE_VMDEV" = "" ]; then
		fsck_ufs -y "$VOLPART"
	fi

	if [ "$EZHYVE_DEVTYPE" = "raw" ] && [ ! "$EZHYVE_VMDEV" = "" ] && [ "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		mdconfig -du "$EZHYVE_VMDEV" || perror "error destroying -> $EZHYVE_VMDEV <- "
	fi

	# set GRUBBOOTCMD and GRUBISOCMD correctly
	if [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		# TODO: add a check if the vars are set for non linux?
		GRUBBOOTCMD="${GRUBBOOTCMD} -m $EZHYVE_DEVICEMAP -M $EZHYVE_RAMSIZE $EZHYVE_VM_NAME"
		GRUBISOCMD="${GRUBISOCMD} -m $EZHYVE_DEVICEMAP -M $EZHYVE_RAMSIZE $EZHYVE_VM_NAME"
	fi

	# bhyve load or grub-bhyve
	if [ "$EZHYVE_VM_TYPE" = "FreeBSD" ] && [ "$CDBOOT" = "false" ]; then
		echo "bhyveload -m $EZHYVE_RAMSIZE -d $EZHYVE_IMAGEPATH $EZHYVE_VM_NAME"
		bhyveload -m $EZHYVE_RAMSIZE -d $EZHYVE_IMAGEPATH $EZHYVE_VM_NAME
	elif [ "$EZHYVE_VM_TYPE" = "FreeBSD" ] && [ "$CDBOOT" = "true" ]; then
		if [ ! -e $EZHYVE_ISOIMGPATH ]; then
			perror "iso $EZHYVE_ISOIMGPATH not found"
		fi
		echo "bhyveload -m $EZHYVE_RAMSIZE -d $EZHYVE_ISOIMGPATH $EZHYVE_VM_NAME"
		bhyveload -m $EZHYVE_RAMSIZE -d $EZHYVE_ISOIMGPATH $EZHYVE_VM_NAME
	elif [ ! -e "$EZHYVE_DEVICEMAP" ]; then
		perror "device map does not exist"
	elif [ ! -e "$EZHYVE_IMAGEPATH" ]; then
		perror "image $EZHYVE_IMAGEPATH does not exist."
	elif [ "$CDBOOT" = "false" ] && [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ] && [ -e "$EZHYVE_ISOIMGPATH" ]; then
		ezhyve_grubcheck
		if [ ! -e "$EZHYVE_ISOIMGPATH" ]; then
			perror "$EZHYVE_ISOIMGPATH not found"
		fi
		echo "ezhyve: Running the grub command:"
		echo "$GRUBBOOTCMD" > $PATH_BHYVEVMS/$EZHYVE_VM_NAME/GRUBBOOTCMD
		eval $GRUBBOOTCMD
	elif [ "$CDBOOT" = "true" ] && [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ] && [ -e "$EZHYVE_ISOIMGPATH" ]; then
		ezhyve_grubcheck
		if [ ! -e "$EZHYVE_ISOIMGPATH" ]; then
			perror "$EZHYVE_ISOIMGPATH not found"
		fi
		echo "ezhyve_boot: Running the grub command:"
		echo "$GRUBISOCMD" > $PATH_BHYVEVMS/$EZHYVE_VM_NAME/GRUBISOCMD
		eval $GRUBISOCMD
	fi

	if [ ! -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "ezhyve_boot: $EZHYVE_VM_NAME failed to load! Exiting."
	else
		echo "ezhyve_boot: $EZHYVE_VM_NAME appears to have loaded."
	fi

	if [ "$EZHYVE_DEVTYPE" = "raw" ]; then
		if [ ! -e $EZHYVE_IMAGEPATH ]; then
			perror "ezhyve_boot $EZHYVE_IMAGEPATH does not exist! Exiting."
		fi
	elif [ ! -e "$EZHYVE_VMDEV" ]; then
		perror "ezhyve_boot $EZHYVE_VMDEV does not exist! Exiting."
	fi

	if [ ! -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		perror "ezhyve_boot $EZHYVE_VM_NAME is not loaded! Exiting."
	fi

	echo "ezhyve_boot Starting Networking. \"File Exists\" warnings are okay."
	echo "ifconfig tap$EZHYVE_VMID down"
	ifconfig tap$EZHYVE_VMID down
	echo "ifconfig tap$EZHYVE_VMID destroy"
	ifconfig tap$EZHYVE_VMID destroy
	echo "ifconfig tap$EZHYVE_VMID create"
	ifconfig tap$EZHYVE_VMID create
	echo "ifconfig bridge$BRIDGE addm tap$EZHYVE_VMID addm $NIC up"
	ifconfig bridge$BRIDGE addm tap$EZHYVE_VMID addm $NIC up
	echo "ifconfig tap$EZHYVE_VMID up"
	ifconfig tap$EZHYVE_VMID up

	if [ "$EZHYVE_CONSOLE" = "nmdm" ]; then
		CONSOLESTR="-S 31,uart,/dev/nmdm${EZHYVE_VMID}A"
	elif [ "$EZHYVE_CONSOLE" = "lpc" ]; then
		CONSOLESTR="-s 31,lpc -l com1,/dev/nmdm${EZHYVE_VMID}A"
	else
		CONSOLESTR="-S 31,uart,stdio"
	fi

	if [ "$CDBOOT" = "true" ]; then
		ISO="-s 4,ahci-cd,$EZHYVE_ISOIMGPATH"
	fi

	BHYVECMD="/usr/sbin/bhyve \
                -c $EZHYVE_CPUNUM \
                -m $EZHYVE_RAMSIZE -A -I -H \
                $BHYVEFLAGS \
                -s 0,$HOSTBRIDGE"hostbridge" \
                -s 2,$EZHYVE_VIRTIO,$EZHYVE_IMAGEPATH \
                -s 3,virtio-net,tap$EZHYVE_VMID \
                $ISO \
                $CONSOLESTR \
                $EZHYVE_VM_NAME
                "	

	echo "BHYVECMD will be $BHYVECMD"
	
	if [ "$EZHYVE_CONSOLE" = "default" ]; then
		eval $BHYVECMD
		ezhyve_destroy
	elif [ "$EZHYVE_CONSOLE" = "nmdm" ]; then
		if [ ! "$( kldstat | grep -o nmdm.ko)" = "nmdm.ko" ]; then
			echo "ezhyve_boot nmdm.ko kernel module is not loaded."
			kldload nmdm.ko
		else
			echo "ezhyve_boot nmdm.ko is loaded."
		fi
		echo "ezhyve_boot Booting $EZHYVE_VM_NAME on console /dev/nmdm${EZHYVE_VMID}A"
		eval $BHYVECMD &
	elif [ "$EZHYVE_CONSOLE" = "lpc" ]; then
		echo "ezhyve_boot Booting $EZHYVE_VM_NAME on console /dev/nmdm${EZHYVE_VMID}A"
		eval $BHYVECMD &
	elif [ "$EZHYVE_CONSOLE" = "tmux" ]; then
		echo "ezhyve_boot Remember to destroy $EZHYVE_VM_NAME after shutdown"
		echo
		/usr/local/bin/tmux new -s $EZHYVE_VM_NAME " eval $BHYVECMD "
	elif [ "$EZHYVE_CONSOLE" = "tmux-detached" ]; then
		/usr/local/bin/tmux new -d -s $EZHYVE_VM_NAME " eval $BHYVECMD "
		echo "ezhyve_boot Remember to destroy $EZHYVE_VM_NAME after shutdown"
		echo "ezhyve_boot Listing tmux sessions:"
		tmux list-sessions
		echo "Attach to $EZHYVE_VM_NAME with: tmux attach-session -t $EZHYVE_VM_NAME"
		echo "Hint: CTRL-b d to detach from it"
	else
		perror "Console not defined! Exiting."
	fi
}

ezhyve_validateconf() {
	# TODO
}


perror() {
	echo -e "$*" >&2; exit 1; 
}
