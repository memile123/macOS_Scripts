#!/bin/bash

############################################################
# Grant standard users access to Date and Time preferences #
############################################################

#########################
#       Functions       #
#########################

function postChangeCheck() {
# Check the changes have been applied

# Create temporary verison of the new preference file
security authorizationdb read system.preferences.datetime > /tmp/system.preferences.datetime.modified

# Populate variable to check the values set
USER_AUTH=$(/usr/libexec/PlistBuddy -c "print rule" /tmp/system.preferences.datetime.modified | sed '2q;d' | sed 's/\ //g')
#or using different sed command to read line two and delete white spacing before the string
#USER_AUTH=(/usr/libexec/PlistBuddy -c "print rule" /tmp/system.preferences.datetime.modified | sed -n '2p'| sed -e 's/^[ \]*//g')

if [[ $USER_AUTH == "allow" ]]; then

	echo "Standard user granted access to Date & Time preferences"

else

	echo "Setting access to Date & Time preferences failed"
	exit 1

fi

rm -f /tmp/system.preferences.datetime.modified

}


##########################
#   script starts here   #
##########################

# If the original files already exist then apply the changes

	if [[ -d "/usr/local/DateTime_Prefs/" ]]; then

		echo "Original preferences already backed up, setting authorisation rights..."
		security authorizationdb write system.preferences.datetime allow

else

# Copy the original DateTime preferences files to a root folder and then apply the changes

	if [[ ! -d "/usr/local/DateTime_Prefs/" ]]; then

		echo "Backing up preferences..."
		mkdir /usr/local/DateTime_Prefs

		security authorizationdb read system.preferences.datetime > /usr/local/DateTime_Prefs/system.preferences.datetime

		echo "Setting authorisation rights..."
		security authorizationdb write system.preferences.datetime allow

	fi

fi

echo "Checking authorisation rights have been set successfully..."
postChangeCheck

exit 0