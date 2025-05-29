ROBOT_NUMBER=__ALL__ # set this to between 0-154

DHCPCDCONF=/etc/dhcpcd.conf
WINTERFACE="wlan0"
GATEWAY=192.168.0.1
NAMESERVER=192.168.0.1
CIDR=20
BASEIP=192.168.9.
BASEN=100

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

if [ "$ROBOT_NUMBER" == "__ASK__" ]; then
    read -p "Enter robot number (0-154): " N
else
    N=$ROBOT_NUMBER
fi

if [ -z "$N" ]; then
	echo "Please set \$ROBOT_NUMBER to the number of this robot. Acceptable values are 0-154."
	exit 1
elif [ $N -gt 154 -a $N -lt 0 ]; then
    echo "Please set \$ROBOT_NUMBER to the number of this robot. Acceptable values are 0-154."
    echo "N=$N is not a valid number."
    exit 1
fi

NFORMATTED=$(printf "%02d" $N)
NEWNAME=turbopi-$NFORMATTED

# make sure dhcpcd.conf exists
sudo touch $DHCPCDCONF

PATTERN="^interface\ ${WINTERFACE}"

if grep -q "${PATTERN}" $DHCPCDCONF; then
    echo "interface $WINTERFACE already exists in $DHCPCDCONF."
    echo "Please manually remove it and the 'static' and 'domain_name_servers' entries after it and try again."
    echo "i.e. sudo nano $DHCPCDCONF"
    read -sp "Press any key to skip network configuration, or CTRL-C to exit." -N 1
    echo
else
    echo "We will set up $WINTERFACE in $DHCPCDCONF"
    echo "with the following options:"
    echo "Static IP address: $BASEIP$N/$CIDR"
    echo "Gateway: $GATEWAY"
    echo "Nameserver: $NAMESERVER"
    echo "Also, we will set the hostname to:"
    echo "Hostname: $NEWNAME"
    read -sp "Continuing in 8 seconds. Press any key to continue, or CTRL-C to exit." -t 8 -N 1
    echo

    echo "Writing 5 lines to $DHCPCDCONF..."

	echo -e "\n" | sudo tee -a $DHCPCDCONF
    echo -e "interface $WINTERFACE" | sudo tee -a $DHCPCDCONF
    echo -e "static ip_address=$BASEIP$N/$CIDR" | sudo tee -a $DHCPCDCONF
    echo -e "static routers=$GATEWAY" | sudo tee -a $DHCPCDCONF
    echo -e "domain_name_servers=$NAMESERVER" | sudo tee -a $DHCPCDCONF
fi

echo Changing hostname from $(hostname) to $NEWNAME
# set hostname
sudo hostnamectl set-hostname $NEWNAME

echo Done.
