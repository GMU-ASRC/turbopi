ROBOT_NUMBER = __ASK__  # set this to between 0-154

DHCPCDCONF = /etc/dhcpcd.conf
WINTERFACE = wlan0
GATEWAY = 192.168.0.1
NAMESERVER = 192.168.0.1
CIDR = 20
BASEIP = 192.168.9.
BASEN = 100

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
    echo "N = $N is not a valid number."
    exit 1
fi

$NFORMATTED = $(printf "%03d" $N)

# make sure dhcpcd.conf exists
touch $DHCPCDCONF

if [ -z "$(grep '^interface $WINTERFACE' $DHCPCDCONF)" ]; then
    echo "interface $WINTERFACE already exists in $DHCPCDCONF."
    echo "Please manually remove it  and the following lines and try again."
    echo "i.e. sudo nano $DHCPCDCONF"
    exit 1
fi

echo -e "interface $WINTERFACE" | sudo tee -a $DHCPCDCONF
echo -e "static ip_address=$BASEIP$N/$CIDR" | sudo tee -a $DHCPCDCONF
echo -e "static routers=$GATEWAY" | sudo tee -a $DHCPCDCONF
echo -e "domain_name_servers=$NAMESERVER" | sudo tee -a $DHCPCDCONF

# set hostname
sudo hostnamectl set-hostname turbopi-$NFORMATTED
