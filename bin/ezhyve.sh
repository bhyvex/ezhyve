#!/bin/sh
# Version 0.01

# TODO: need to handle pfsense vm type (freenas ...) ... maybe as -v?

# source our functions.sh
DIR="`dirname $0`/../etc"
if [ -e ${DIR}/ezhyve/functions.sh ]; then
	. ${DIR}/ezhyve/functions.sh
else
	echo "couldn't find functions.sh" && exit 1
fi

# source the bhyve.conf
if [ -e ${DIR}/ezhyve/ezhyve.conf ]; then
	. ${DIR}/ezhyve/ezhyve.conf
else
	perror "couldn't find ezhyve.conf"
fi


ezhyve_pretest

scriptname=`basename -- $0`

ezhyve_usage="please see README for now, call ${scriptname} create/cdboot to see usage for create/cdboot"

ezhyve_create_usage1="${scriptname} create [-t FreeBSD (Linux, OpenBSD)] [-v 9.2-RELEASE (debian...)] [-m 1024 (RAM in MB)] [-d 2G (Disksize in GB)] [-p 1 (Num of. CPUs)] \n"
ezhyve_create_usage2="[-c default (console type)] [-l mbr (gpt)] [-o ahci-hd (virtio-blk)] [-D /dev/foo (e.g. zvol/zroot/vm0)] [-i /path/to/img.iso] vmname"
ezhyve_start_usage="${scriptname} start vmname"
ezhyve_delete_usage="${scriptname} delete vmname"
ezhyve_provision_usage="${scriptname} provision vmname"
ezhyve_fetch_usage="${scriptname} fetch vmname"
ezhyve_debug_usage="${scriptname} debug vmname"
ezhyve_cdboot_usage="${scriptname} cdboot [-i /path/to/img.iso] vmname"
ezhyve_console_usage="${scriptname} console vmname"
ezhyve_stop_usage="${scriptname} stop vmname"
ezhyve_grub_usage="${scriptname} stop vmname"

[ $# -gt 0 ] || perror ${ezhyve_usage1} ${ezhyve_usage2} ${ezhyve_usage3} ${ezhyve_usage4} ${ezhyve_usage5} ${ezhyve_usage6} ${ezhyve_usage7} ${ezhyve_usage8} ${ezhyve_usage9} ${ezhyve_usage10} ${ezhyve_usage11} ${ezhyve_usage12} ${ezhyve_usage13} ${ezhyve_usage14} ${ezhyve_usage15} ${ezhyve_usage16}

case "$1" in
create)
	echo "creating bhyve vm";
	shift; while getopts :t:v:m:d:p:c:l:i:D:o: arg; do case ${arg} in
	t) EZHYVE_VM_TYPE=${OPTARG};; # defaults to FreeBSD 
	v) EZHYVE_OS_VERSION=${OPTARG};; # defaults to 9.2-RELEASE
	m) EZHYVE_RAMSIZE=${OPTARG};; # defaults to 512
	d) EZHYVE_DISKSIZE=${OPTARG};; # defaults to 2G
	p) EZHYVE_CPUNUM=${OPTARG};; #defaults to 1
	c) EZHYVE_CONSOLE=${OPTARG};; #defaults to default
	l) EZHYVE_LAYOUT=${OPTARG};; # defaults to gpt
	o) VIRTIOTMP=${OPTARG};; # defaults to ahci-hd
	i) EZHYVE_ISOIMGPATH=${OPTARG};; # path to iso default ""
	D) EZHYVE_VMDEV=${OPTARG};; # default ""
	?) perror ${ezhyve_create_usage1} ${ezhyve_create_usage2};;
	esac; done; shift $(( ${OPTIND} - 1 ))

	# we need at least a name
	EZHYVE_VM_NAME=$1
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_create_usage1} ${ezhyve_create_usage2};

	# non FreeBSD and -D? I dunno. Not supported for now.
	if [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ] && [ ! "$EZHYVE_VMDEV" = "" ]; then
		perror "\-D and non FreeBSD not allowed (for now?)";
	fi
	# TODO: do we handle $EZHYVE_VMDEV correctly?
	
	# generate an VMID ... for tapX ... nmdmX
	# TODO: needs rework, starts at 1 (so tap1 ...) make startpoint customizable?
	ezhyve_generatevmid

	# check if we already have a VM config and VM dir
	ezhyve_vmcheck $EZHYVE_VM_NAME;
	
	# load the template from $PATH_VMTEMPLATE/$EZHYVE_VM_TYPE/$EZHYVE_OS_VERSION
	ezhyve_gettemplate $EZHYVE_VM_TYPE $EZHYVE_OS_VERSION;

	if [ ! -e $PATH_BHYVEVMS/$EZHYVE_VM_NAME ]; then
		mkdir -p $PATH_BHYVEVMS/$EZHYVE_VM_NAME || perror "couldn't create VM Dir $PATH_BHYVEVMS/$EZHYVE_VM_NAME";
	fi

	# TODO: set EZHYVE_ISOIMGPATH
	# seems to work :)
	if [ ! "$EZHYVE_ISOIMGPATH" = "" ]; then
		if [ -e $EZHYVE_ISOIMGPATH ]; then
			echo "EZHYVE_ISOIMGPATH is $EZHYVE_ISOIMGPATH";
		else 
			perror "$EZHYVE_ISOIMGPATH does not exist."
		fi
	elif [ "$EZHYVE_ISOIMGPATH" = "" ] && [ ! "$ISOIMG" = "" ]; then
		if [ -e $PATH_ISOFILES/$ISOIMG ]; then
			echo "EZHYVE_ISOIMGPATH is $ISOIMG";
			EZHYVE_ISOIMGPATH="$PATH_ISOFILES/$ISOIMG"
		else
			EZHYVE_ISOIMGPATH="$PATH_ISOFILES/$ISOIMG"
			echo "$ISOIMG does not exist in $PATH_ISOFILES; run ${scriptname} fetch vmname first";
		fi
	fi
		echo "EZHYVE_ISOIMGPATH is -> $EZHYVE_ISOIMGPATH <- "
	
	# TODO: handle virtio
	# seems to work :)
	if [ ! "$VIRTIO" = "" ]; then
		# from template
		EZHYVE_VIRTIO="$VIRTIO"
	elif [ ! "$VIRTIOTMP" = "" ]; then
		# from command line
		EZHYVE_VIRTIO="$VIRTIOTMP"
	fi
	# otherwise default should be ahci-hd
	# TODO: make it match valid options
	if [ "$EZHYVE_VIRTIO" = "" ]; then
		perror "EZHYVE_VIRTIO not set correctly".
	fi
	echo "EZHYVE_VIRTIO is -> $EZHYVE_VIRTIO <- (needs to be set!)"
	
	# TODO: we can delete this line i guess.
	EZHYVE_IMAGEPATH="$PATH_BHYVEVMS/$EZHYVE_VM_NAME/$EZHYVE_VM_NAME.img$"

	# TODO: handle -d and -D ... makes no sense together
	# creating image when -D is not set
	if [ "$EZHYVE_VMDEV" = "" ]; then
		EZHYVE_IMAGEPATH="$PATH_BHYVEVMS/$EZHYVE_VM_NAME/$EZHYVE_VM_NAME.img";
		EZHYVE_DEVTYPE="raw";
		createimage;
	else
		EZHYVE_IMAGEPATH="";
	fi

	# Assuming grub-bhyve if EZHYVE_VM_TYPE is not FreeBSD 
	if [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		ezhyve_grubcheck;
		# setting device.map path to vm config
		EZHYVE_DEVICEMAP="$PATH_BHYVEVMS/$EZHYVE_VM_NAME/device.map"
		# create device.map
		echo "(hd0) $EZHYVE_IMAGEPATH" > $EZHYVE_DEVICEMAP
		# only add cd0 when iso image was specified
		if [ ! $EZHYVE_ISOIMGPATH = "" ] && [ -e "$EZHYVE_ISOIMGPATH" ]; then
			echo "(cd0) $EZHYVE_ISOIMGPATH" >> $EZHYVE_DEVICEMAP
		fi

	fi

	if [ ! $VIRTIO = "" ]; then
		EZHYVE_VIRTIO=$VIRTIO;
	fi

	ezhyve_writeconfig;

	;;
start)
	# load config and boot
	echo "starting bhyve vm";
	# TODO: for now nothing is overwriteable via commandline, edit config file instead
	# but would be cool
	# TODO: start all when vmname not given (rc.conf var? ezhyve.conf var?)
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_start_usage};
	ezhyve_getconfig $EZHYVE_VM_NAME
	ezhyve_boot
	
	# TODO: boots image
	;;
stop)
	echo "stoping vm";
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_stop_usage};
	ezhyve_getconfig $EZHYVE_VM_NAME
	ezhyve_destroy
	;;
cdboot)
	echo "entering cdboot";
	shift; while getopts :i: arg; do case ${arg} in
	i) ISOTMP=${OPTARG};;
	?) perror ${ezhyve_cdboot_usage};;
	esac; done; shift $(( ${OPTIND} - 1 ))
	EZHYVE_VM_NAME=$1
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_cdboot_usage};
	ezhyve_getconfig $EZHYVE_VM_NAME

	if [ ! "$ISOTMP" = "" ]; then	
		ezhyve_checkiso $ISOTMP
		if [ -e "$ISOTMP" ]; then
			EZHYVE_ISOIMGPATH=$ISOTMP
		fi
	fi

	ezhyve_checkiso $EZHYVE_ISOIMGPATH

	# TODO: we have to rewrite the device.map for ! FreeBSD guests to be able to cdboot
	# see if this works ...
	if [ ! "$EZHYVE_VM_TYPE" = "FreeBSD" ] && [ ! "$ISOTMP" = "" ]; then
		ezhyve_cdbootdevicemap
	fi

	if [ "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		echo "if you install via iso don't forget to set \"console "/usr/libexec/getty std.9600" vt100 on secure\" in \"/etc/ttys\""
	fi

	CDBOOT=true
	ezhyve_boot
	# TODO: boots cd0 (iso) if grub or iso if FreeBSD
	;;
provision)
	# TODO: another switch to specify something like ezjail flavour (but only if we do provisioning)
	echo "provision a FreeBSD VM";
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_provision_usage};
	ezhyve_getconfig $EZHYVE_VM_NAME
	fbsdfetch;
	fbsdformatimage;
	fbsdprovision;
	;;
delete)
	echo "ezhyve deleting VM";
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_fetch_usage};
	if [ ! -e /dev/vmm/$EZHYVE_VM_NAME ]; then
		ezhyve_vmdelete $EZHYVE_VM_NAME;
	fi
	;;
fetch)
	echo "fetching iso/img";
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_provision_usage};
	ezhyve_getconfig $EZHYVE_VM_NAME
	ezhyve_fetch $ISOSITE $ISOIMGISOSITE $ISOIMG
	;;
list)
	echo "listening running vms";
	ezhyve_list
	;;
debug)
	echo "entering debugging mode".
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_debug_usage};
	ezhyve_list
	/usr/sbin/bhyvectl --get-all --vm="$EZHYVE_VM_NAM" || perror "error getting vm $EZHYVE_VM_NAM"
	;;
console)
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_console_usage};
	ezhyve_getconfig $EZHYVE_VM_NAME
	ezhyve_attach
	;;
grub)
	EZHYVE_VM_NAME=$2
	[ "${EZHYVE_VM_NAME}" -a $# -ge 1 ] || perror ${ezhyve_debug_usage};
	ezhyve_getconfig $EZHYVE_VM_NAME
	if [ "$EZHYVE_VM_TYPE" = "FreeBSD" ]; then
		perror "${scriptname} grub vmname not supported for FreeBSD"
	fi
	ezhyve_grub
	;;
*)
	perror ${ezhyve_usage1} ${ezhyve_usage2} ${ezhyve_usage3} ${ezhyve_usage4} ${ezhyve_usage5} ${ezhyve_usage6} ${ezhyve_usage7} ${ezhyve_usage8} ${ezhyve_usage9} ${ezhyve_usage10} ${ezhyve_usage11} ${ezhyve_usage12} ${ezhyve_usage13} ${ezhyve_usage14} ${ezhyve_usage15} ${ezhyve_usage16}
	;;
esac
