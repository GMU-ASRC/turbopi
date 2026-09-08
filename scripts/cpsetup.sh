if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

dos2unix -q ./config
source ./config

# exit on error
set -e

echo "Copying setup scripts to $SETUPSCRIPTS"

dos2unix -q *.sh
mkdir -p $SETUPSCRIPTS
cp ./* $SETUPSCRIPTS
chmod +x $SETUPSCRIPTS/*.sh
set +e
chmod +x $SETUPSCRIPTS/*.secret
set -e
chmod +x $SETUPSCRIPTS/config
# rm $SETUPSCRIPTS/*.secret
cd $SETUPSCRIPTS