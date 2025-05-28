#!/bin/bash

SETUPSCRIPTS=/home/pi/setupscripts

crontab -l | grep -v '$SETUPSCRIPTS/provision2s.sh' | crontab -
COMMAND="source '$SETUPSCRIPTS/provision2.sh' $1"
SHOWCOMMAND="lxterminal -e '$COMMAND'"
if su pi -lc "lxterminal -e 'sleep 1'"; then
	su pi -s /bin/bash -lc "$SHOWCOMMAND"
else
	su pi -s /bin/bash -lc "$COMMAND"
fi
read -N 1 -sp "Press any key to exit."
echo
exit $RET

