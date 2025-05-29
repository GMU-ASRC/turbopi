#!/bin/bash
# this file will automatically be run as root

echo Starting resume_turbopi_setup.sh
echo $1
echo $2
cd $2
echo in $PWD
source ./config  # EDITTAG:configsource

# crontab -lu root | grep -v "${SETUPSCRIPTS}/provision2s.sh" | crontab -u root -
rm -f /etc/systemd/system/resume_turbopi_setup.service
touch $SETUPSCRIPTS/setup2sran
CMD="$SETUPSCRIPTS/provision2.sh $1"
RUNCOMMAND="echo ${SETUPSCRIPTS}/provision2.sh ${1} | /bin/bash -is"
SHOWCOMMAND="lxterminal -e '$RUNCOMMAND'"
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

