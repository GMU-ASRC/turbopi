#!/bin/bash
# this file will automatically be run as root

source ./config

crontab -lu root | grep -v "${SETUPSCRIPTS}/provision2s.sh" | crontab -u root -
touch $SETUPSCRIPTS/setup2sran
CMD="$SETUPSCRIPTS/provision2.sh $1"
RUNCOMMAND='/bin/bash -i "$CMD"'
DISPLAYCMD="echo ${SETUPSCRIPTS}/provision2.sh ${1} | /bin/bash -is"
SHOWCOMMAND="lxterminal -e '$DISPLAYCMD'"
if su $U -c "lxterminal -e 'echo hi'"; then  # test if lxterminal is available
	echo running in lxterminal
	sleep 0.1
	su $U -Pc "$SHOWCOMMAND"
else
	echo running here
	su $U -Pc "$RUNCOMMAND"
fi
read -N 1 -sp "Press any key to exit."
echo
exit $RET

