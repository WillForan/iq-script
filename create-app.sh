#!/usr/bin/bash
set -eou pipefail
trap 'e=$?; [ $e -gt 0 ] && echo "$0 exited in error $e"' EXIT


# defaults
DEVICE=vivoactive_hr
MIN_SDK=2.4.1
DEVELOPER_KEY=$HOME/passwd/garmin/developer_key.der

[ $# -lt 1 ] &&
   echo "USAGE: $(basename $0) path/name [device=$DEVICE] [min_sdk=$MIN_SDK] [key=$DEVELOPER_KEY]" &&
   exit 1

# check we can find SDK, xml
CONNECTIQ_HOME=$(dirname $(which monkeyc))
[ -z "$CONNECTIQ_HOME" ] &&
   echo "ERROR: cannot find Connect IQ SDK" &&
   exit 1
! which xml >/dev/null 2>&1 && echo "ERROR: missing 'xmlstarlet'. get with brew/apt/pacman" && exit 1

# APP PARAMS
COMPLETE_PATH="$1"; shift
[ $# -ge 1 ] && DEVICE="$1" && shift
[ $# -ge 1 ] && MIN_SDK="$1" && shift
[ $# -ge 1 ] && DEVELOPER_KEY="$1" && shift

# Make sure we are specifying a real device
devlistcmd="xml sel -t -v 'monkeybrains/devices/device/@id' '$CONNECTIQ_HOME/devices.xml'"
! eval "$devlistcmd" |grep -q ^$DEVICE$ &&
   echo "Device '$DEVICE' not known! see: $devlistcmd" && exit 1

# should create once. if app dir exists, bail.
test -d $COMPLETE_PATH && echo "ERROR: app path already exists '$COMPLETE_PATH'" && exit 1

# make the kye if we don't have it
if [ ! -r $DEVELOPER_KEY ]; then
   echo "WARNING: no key '$DEVELOPER_KEY'; making"
   keydir="$(dirname "$DEVELOPER_KEY")"
   keyname="$(basename "$DEVELOPER_KEY" .der).pem" 
   [ ! -d $keydir ] && mkdir -p $keydir
   pemkey=$keydir/$keyname
   openssl genrsa -out $pemkey 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in $pemkey -out $DEVELOPER_KEY -nocrypt
fi

#APP_PREFIXE=$(echo $APP_NAME | tr '[:upper:]' '[:lower:]' | tr -d '-')
APP_NAME="$(basename "$COMPLETE_PATH")"
APP_PREFIXE="${APP_NAME}"
APP_ENTRY="${APP_PREFIXE}App"
APP_DELEGATE="${APP_PREFIXE}Delegate"
APP_VIEW="${APP_PREFIXE}View"
APP_MENU_DELEGATE="${APP_PREFIXE}MenuDelegate"


# WATCH-APP TEMPLATE
cp -r $CONNECTIQ_HOME/templates/watch-app/simple/ $COMPLETE_PATH/

# APP RESOURCE
RESOURCE_PATH=$(find $COMPLETE_PATH -path "$COMPLETE_PATH/resources*.xml" | xargs | tr ' ' ':')

# APP SOURCES
mv $COMPLETE_PATH/source/App.mc $COMPLETE_PATH/source/${APP_PREFIXE}App.mc
mv $COMPLETE_PATH/source/View.mc $COMPLETE_PATH/source/${APP_PREFIXE}View.mc
mv $COMPLETE_PATH/source/MenuDelegate.mc $COMPLETE_PATH/source/${APP_PREFIXE}MenuDelegate.mc
mv $COMPLETE_PATH/source/Delegate.mc $COMPLETE_PATH/source/${APP_PREFIXE}Delegate.mc

#UUID=$(cat /proc/sys/kernel/random/uuid | tr '[:upper:]' '[:lower:]' | tr -d '-') #UUID FOR LINUX
UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')

# UPDATE manifest.xml
upman(){ xml ed --inplace $@ ${COMPLETE_PATH}/manifest.xml; }
upman -u "/iq:manifest/iq:application/@id" -v ${UUID}
upman -u "/iq:manifest/iq:application/@type" -v 'watch-app'
upman -u "/iq:manifest/iq:application/@name" -v '@Strings.AppName' 
upman -u "/iq:manifest/iq:application/@launcherIcon" -v '@Drawables.LauncherIcon'
upman -u "/iq:manifest/iq:application/@entry" -v ${APP_ENTRY} 
upman -u "/iq:manifest/iq:application/@minSdkVersion" -v ${MIN_SDK} 
upman -s "/iq:manifest/iq:application/iq:products" -t elem -n iq:product -v '""'
upman -i '/iq:manifest/*/iq:products/*' -t attr -n id -v "$DEVICE"



# UPDATE source files
# APP
sed -i -e "s!\${appClassName}!$APP_ENTRY!g" ${COMPLETE_PATH}/source/${APP_ENTRY}.mc
sed -i -e "s!\${delegateClassName}!$APP_DELEGATE!g" ${COMPLETE_PATH}/source/${APP_ENTRY}.mc
sed -i -e "s!\${viewClassName}!$APP_VIEW!g" ${COMPLETE_PATH}/source/${APP_ENTRY}.mc

# VIEW
sed -i -e "s!\${viewClassName}!$APP_VIEW!g" ${COMPLETE_PATH}/source/${APP_VIEW}.mc

# DELEGATE
sed -i -e "s!\${delegateClassName}!$APP_DELEGATE!g" ${COMPLETE_PATH}/source/${APP_DELEGATE}.mc
sed -i -e "s!\${menuDelegateClassName}!$APP_MENU_DELEGATE!g" ${COMPLETE_PATH}/source/${APP_DELEGATE}.mc

# MENU DELEGATE
sed -i -e "s!\${menuDelegateClassName}!$APP_MENU_DELEGATE!g" ${COMPLETE_PATH}/source/${APP_MENU_DELEGATE}.mc

# UPDATE resources
sed -i -e "s!\${appName}!$APP_NAME!g" ${COMPLETE_PATH}/resources/strings/strings.xml

# ADD Makefile
RDIR="$(dirname "$0")"
echo "
DEVELOPER_KEY:=$DEVELOPER_KEY
DEVICE:=$DEVICE" > ${COMPLETE_PATH}/Makefile
cat Makefile >> ${COMPLETE_PATH}/Makefile


# CLEAN
rm -f ${COMPLETE_PATH}/*.sh-e ${COMPLETE_PATH}/resources/strings/*.xml-e ${COMPLETE_PATH}/source/*.mc-e

#monkeyc -o ${COMPLETE_PATH}/${APP_NAME}.prg -d ${DEVICE} -m ${COMPLETE_PATH}/manifest.xml -z ${RESOURCE_PATH} ${COMPLETE_PATH}/source/*.mc -w -y ${DEVELOPER_KEY}
cd $COMPLETE_PATH
make
