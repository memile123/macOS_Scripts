#!/bin/bash

########################################################################
#      Uninstall iWork, Garageband and iMovie During Enrolment         #
################### Written by Phil Walker Feb 2010 ####################
########################################################################

#Garageband, iMovie, Keynote, Numbers and Pages are installed on all new Macs shipped by Apple
#As standard the App Store is restricted on all Bauer Macs preventing these apps from being updated
#VPP delivered versions of all of the below apps can be installed via Self Service if required

########################################################################
#                            Variables                                 #
########################################################################

#Non VPP Apple apps check
appleApps=$(ls /Applications/ | grep -i "Garageband\|iMovie\|Keynote\|Numbers\|Pages" | awk 'END { print NR }')
#Check to see if the DEPNotify app is open
depNotify=$(ps aux | grep -v grep | grep "DEPNotify.app")

########################################################################
#                         Script starts here                           #
########################################################################

#Confirm that the Mac is currently being enrolled
if [[ "${depNotify}" != "" ]]; then
  echo "DEP Notify process running, continuing..."
else
	echo "DEP Notify process not found, exiting..."
  exit 0
fi

if [[ "$appleApps" -ne "0" ]]; then

  echo "Uninstalling iWork apps, Garageband and iMovie..."
    rm -rf "/Applications/Garageband.app" 2>/dev/null
    rm -rf "/Applications/iMovie.app" 2>/dev/null
    rm -rf "/Applications/Keynote.app" 2>/dev/null
    rm -rf "/Applications/Numbers.app" 2>/dev/null
    rm -rf "/Applications/Pages.app" 2>/dev/null

    appleApps=$(ls /Applications/ | grep -i "Garageband\|iMovie\|Keynote\|Numbers\|Pages" | awk 'END { print NR }')
      if [[ "$appleApps" -eq "0" ]]; then
        echo "iWork apps, Garageband and iMovie uninstalled successfully"
      else
        echo "iWork apps, Garageband and iMovie uninstallation failed, manual removal required!"
      fi
else


  echo "iWork apps, Garageband and iMovie not found, nothing to do"
fi

exit 0
