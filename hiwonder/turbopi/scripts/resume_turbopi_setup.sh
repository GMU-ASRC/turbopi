#!/bin/bash

echo Starting resume_turbopi_setup.sh
echo $1
echo in $PWD
echo as $USER $(whoami)
export DISPLAY=:0
echo DISPLAY = $DISPLAY

set -e  # exit on error
source ./config  # EDITTAG:configsource

# crontab -lu root | grep -v "${SETUPSCRIPTS}/provision2s.sh" | crontab -u root -
# rm -f /etc/systemd/system/resume_turbopi_setup.service
sudo systemctl disable resume_turbopi_setup.service
touch $SETUPSCRIPTS/setup2sran
CMD="$SETUPSCRIPTS/provision2.sh $1"
RUNCOMMAND="echo ${SETUPSCRIPTS}/provision2.sh ${1} | /bin/bash -is"
SHOWCOMMAND=""
if lxterminal -e echo hi"; then  # test if lxterminal is available
	echo running in lxterminal
	sleep 0.1
	# su $U -Pc "$SHOWCOMMAND"
	lxterminal -e "$RUNCOMMAND"
else
	echo running here
	# su $U -Pc "$RUNCOMMAND"
	source $SETUPSCRIPTS/provision2.sh $1
fi
# read -N 1 -sp "Press any key to exit."
echo
# exit $RET
echo Reached end of resume_turbopi_setup.sh.

