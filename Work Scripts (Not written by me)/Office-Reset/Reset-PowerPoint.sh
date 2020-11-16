#!/bin/zsh

# Script written by Paul Bowden (Software Engineer/Office for Mac at Microsoft) and available from https://office-reset.com/

########################################################################
#                            Variables                                 #
########################################################################

autoload is-at-least
APP_NAME="Microsoft PowerPoint"
APP_GENERATION="2019"
DOWNLOAD_2019="https://go.microsoft.com/fwlink/?linkid=525136"
DOWNLOAD_2016="https://go.microsoft.com/fwlink/?linkid=871751"
OS_VERSION=$(sw_vers -productVersion)

########################################################################
#                            Functions                                 #
########################################################################

GetLoggedInUser() {
	LOGGEDIN=$(/bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}')
	if [ "$LOGGEDIN" = "" ]; then
		echo "$USER"
	else
		echo "$LOGGEDIN"
	fi
}

SetHomeFolder() {
	HOME=$(dscl . read /Users/"$1" NFSHomeDirectory | cut -d ':' -f2 | cut -d ' ' -f2)
	if [ "$HOME" = "" ]; then
		if [ -d "/Users/$1" ]; then
			HOME="/Users/$1"
		else
			HOME=$(eval echo "~$1")
		fi
	fi
}

RepairApp() {
	if [[ "${APP_GENERATION}" == "2016" ]]; then
		DOWNLOAD_URL="${DOWNLOAD_2016}"
	else
		DOWNLOAD_URL="${DOWNLOAD_2019}"
	fi

	DOWNLOAD_FOLDER="/Users/Shared/OnDemandInstaller/"
	if [ -d "$DOWNLOAD_FOLDER" ]; then
		rm -rf "$DOWNLOAD_FOLDER"
	fi
	mkdir -p "$DOWNLOAD_FOLDER"

	CDN_PKG_URL=$(/usr/bin/nscurl --location --head $DOWNLOAD_URL --dump-header - | awk '/Location/' | cut -d ' ' -f2 | tail -1 | awk '{$1=$1};1')
	echo "Office-Reset: Package to download is ${CDN_PKG_URL}"
	CDN_PKG_NAME=$(/usr/bin/basename "${CDN_PKG_URL}")

	CDN_PKG_SIZE=$(/usr/bin/nscurl --location --head $DOWNLOAD_URL --dump-header - | awk '/Content-Length/' | cut -d ' ' -f2 | tail -1 | awk '{$1=$1};1')
	CDN_PKG_MB=$(/bin/expr ${CDN_PKG_SIZE} / 1000 / 1000)
	echo "Office-Reset: Download package is ${CDN_PKG_MB} megabytes in size"

	echo "Office-Reset: Starting ${APP_NAME} package download"
	/usr/bin/nscurl --background --download --large-download --location --download-directory $DOWNLOAD_FOLDER $DOWNLOAD_URL
	echo "Office-Reset: Finished package download"

	LOCAL_PKG_SIZE=$(cd "${DOWNLOAD_FOLDER}" && stat -qf%z "${CDN_PKG_NAME}")
	if [[ "${LOCAL_PKG_SIZE}" == "${CDN_PKG_SIZE}" ]]; then
		echo "Office-Reset: Downloaded package is wholesome"
	else
		echo "Office-Reset: Downloaded package is malformed. Local file size: ${LOCAL_PKG_SIZE}"
		echo "Office-Reset: Please manually download and install ${APP_NAME} from ${CDN_PKG_URL}"
		exit 0
	fi

	LOCAL_PKG_SIGNING=$(/usr/sbin/pkgutil --check-signature ${DOWNLOAD_FOLDER}${CDN_PKG_NAME} | awk '/Developer ID Installer'/ | cut -d ':' -f 2 | awk '{$1=$1};1')
	if [[ "${LOCAL_PKG_SIGNING}" == "Microsoft Corporation (UBF8T346G9)" ]]; then
		echo "Office-Reset: Downloaded package is signed by Microsoft"
	else
		echo "Office-Reset: Downloaded package is not signed by Microsoft"
		echo "Office-Reset: Please manually download and install ${APP_NAME} from ${CDN_PKG_URL}"
		exit 0
	fi

	echo "Office-Reset: Starting package install"
	sudo /usr/sbin/installer -pkg ${DOWNLOAD_FOLDER}${CDN_PKG_NAME} -target /
	if [ $? -eq 0 ]; then
		echo "Office-Reset: Package installed successfully"
	else
		echo "Office-Reset: Package installation failed"
		echo "Office-Reset: Please manually download and install ${APP_NAME} from ${CDN_PKG_URL}"
		exit 0
	fi
	echo "Office-Reset: Exiting without removing configuration data"
	exit 0
}

########################################################################
#                         Script starts here                           #
########################################################################

echo "Office-Reset: Starting Reset-PowerPoint"
LoggedInUser=$(GetLoggedInUser)
SetHomeFolder "$LoggedInUser"
echo "Office-Reset: Running as: $LoggedInUser; Home Folder: $HOME"
# Close PowerPoint
/usr/bin/pkill -9 'Microsoft PowerPoint'
echo "Office-Reset: PowerPoint closed"
# Check the app bundle
if [ -d "/Applications/Microsoft PowerPoint.app" ]; then
	APP_VERSION=$(defaults read /Applications/Microsoft\ PowerPoint.app/Contents/Info.plist CFBundleVersion)
	echo "Office-Reset: Found version ${APP_VERSION} of ${APP_NAME}"
	if ! is-at-least 16.17 $APP_VERSION; then
		APP_GENERATION="2016"
	fi
	if [[ "${APP_GENERATION}" == "2019" ]]; then
		if ! is-at-least 16.34 $APP_VERSION && is-at-least 10.13 $OS_VERSION; then
			echo "Office-Reset: The installed version of ${APP_NAME} (2019 generation) is ancient. Updating it now"
			RepairApp
		fi
	fi
	if [[ "${APP_GENERATION}" == "2016" ]]; then
		if ! is-at-least 16.16 $APP_VERSION; then
			echo "Office-Reset: The installed version of ${APP_NAME} (2016 generation) is ancient. Updating it now"
			RepairApp
		fi
	fi
	echo "Office-Reset: Checking the app bundle for corruption"
	/usr/bin/codesign -vv --deep /Applications/Microsoft\ PowerPoint.app
	if [ $? -gt 0 ]; then
		echo "Office-Reset: The ${APP_NAME} app bundle is damaged and will be removed and reinstalled" 
		/bin/rm -rf /Applications/Microsoft\ PowerPoint.app
		RepairApp
	else
		echo "Office-Reset: Codesign passed successfully"
	fi
else
	echo "Office-Reset: ${APP_NAME} was not found in the default location"
fi
# Config data removal
echo "Office-Reset: Removing configuration data for ${APP_NAME}"
/bin/rm -f "/Library/Preferences/com.microsoft.Powerpoint.plist"
/bin/rm -f "/Library/Managed Preferences/com.microsoft.Powerpoint.plist"
/bin/rm -f "$HOME/Library/Preferences/com.microsoft.Powerpoint.plist"
/bin/rm -rf "$HOME/Library/Containers/com.microsoft.Powerpoint"
/bin/rm -rf "$HOME/Library/Application Scripts/com.microsoft.Powerpoint"
/bin/rm -rf "/Applications/Microsoft PowerPoint.app.installBackup"
/bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Startup.localized/PowerPoint"
/bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.pot"
/bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.potx"
/bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.potm"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Startup.localized/PowerPoint"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.pot"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.potx"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.potm"
/bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Add-Ins/*.ppam"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Add-Ins/*.ppam"
/bin/rm -rf "/Library/Application Support/Microsoft/Office365/User Content.localized/Themes"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Themes"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/mip_policy"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/FontCache"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/ComRPC32"
/bin/rm -rf "$HOME/Library/Group Containers/UBF8T346G9.Office/TemporaryItems"
/bin/rm -f "$HOME/Library/Group Containers/UBF8T346G9.Office/Microsoft Office ACL*"
/bin/rm -f "$HOME/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg"
echo "Office-Reset: Configuration data for ${APP_NAME} removed"
echo "Office-Reset: Finished Reset-PowerPoint"
exit 0