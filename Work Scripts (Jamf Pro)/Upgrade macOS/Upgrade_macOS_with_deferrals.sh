#!/bin/bash

########################################################################
#                 Upgrade macOS with user deferrals                    #
################# Written by Phil Walker August 2019 ###################
########################################################################

#Installer to be deployed separately

########################################################################
#                         Jamf Variables                               #
########################################################################

osInstallerLocation="$4" #The path the to Mac OS installer is pulled in from the policy for flexability e.g /Applications/Install macOS Mojave.app SPACES ARE PRESERVED
requiredSpace="$5" #In GB how many are requried to compelte the update
osName="$6" #The nice name for jamfHelper e.g. macOS Mojave.
policyName="$9" #Policy name for deferral file.

##DEBUG
#osInstallerLocation="/Applications/Install macOS Mojave.app"
#requiredSpace="$5"
#osName="macOS Mojave"
#policyName="macOSMojaveUpgrade" #Policy name for deferral file.

########################################################################
#                            Variables                                 #
########################################################################

#Get the logged in user
loggedInUser=$(python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

#Mac model and marketing name
macModel=$(sysctl -n hw.model)
macModelFull=$(system_profiler SPHardwareDataType | grep "Model Name" | sed 's/Model Name: //' | xargs)

#OS Version Full and Short
osFull=$(sw_vers -productVersion)
osShort=$(sw_vers -productVersion | awk -F. '{print $2}')

#Path to NoMAD Login AD bundle
noLoADBundle="/Library/Security/SecurityAgentPlugins/NoMADLoginAD.bundle"

#Check the logged in user is a local account
mobileAccount=$(dscl . read /Users/${loggedInUser} OriginalNodeName 2>/dev/null)

#Check we have the timer file and if not create it and populate with 5
#which represents the number of defers the end user will have
if [ ! -e /Library/Application\ Support/JAMF/.UpgradeDeferral-${policyName}.txt ]; then
    echo "3" > /Library/Application\ Support/JAMF/.UpgradeDeferral-${policyName}.txt
fi

#Get the value of the timer file and store for later
Timer=$(cat /Library/Application\ Support/JAMF/.UpgradeDeferral-${policyName}.txt)

#Go get the Mojave icon from Apple's website
curl -s --url https://support.apple.com/library/APPLE/APPLECARE_ALLGEOS/SP777/mojave-roundel-240_2x.png > /var/tmp/mojave-roundel-240_2x.png

jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
icon="/var/tmp/mojave-roundel-240_2x.png"
title="Message from Bauer IT"
heading="An important upgrade is availabe for your Mac - $Timer deferral(s) remaining"
description="The ${osName} upgrade includes new features, security updates and performance enhancements.

Would you like to upgrade now? You may choose not to upgrade to ${osName} now, but after $Timer deferrals your mac will be automatically upgraded.

During this upgrade, you will not have access to your computer! The upgrade can take up to 1 hour to complete.

If using a laptop please make sure you are connected to power.

You must ensure all work is saved before clicking the 'Upgrade Now' button. All of your files and Applications will remain exactly as you leave them.

You can also trigger the upgrade via the Self Service Application at any time e.g. over lunch or just before you leave for the day."
##Icon to be used for userDialog
##Default is macOS Mohave Installer logo which is included in the staged installer package
icon="$osInstallerLocation"/Contents/Resources/InstallAssistant.icns
icon_warning=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns

########################################################################
#                            Functions                                 #
########################################################################

function jamfHelperAsktoUpgrade ()
{
HELPER=$( "$jamfHelper" -windowType utility -icon "$icon" -heading "$heading" -alignHeading center -title "$title" -description "$description" -button1 "Later" -button2 "Upgrade Now" -defaultButton "2" )
}

function jamfHelperUpdateConfirm ()
{
#Show a message via Jamf Helper that the update is ready, this is after it has been deferred
HELPER_CONFIRM=$(
"$jamfHelper" -windowType utility -icon "$icon" -title "$title" -heading "    ${osName} upgrade is now ready to be installed     " -description "This upgrade includes new features, security updates and performance enhancements.

Your Mac will restart once complete!

Please save all of your work before clicking install" -lockHUD -timeout 7200 -countdown -alignCountdown center -button1 "Install" -defaultButton "1"
)
}

function jamfHelperInProgress()
{
"$jamfHelper" -windowType utility -title "Message from Bauer IT" -icon "$icon" -heading "Please wait as we prepare your computer for ${osName}..." -description "This process will take approximately 5-10 minutes. Please do not open any documents or applications.
Once completed your computer will reboot and begin the upgrade.

During this upgrade you will not have access to your Mac!
It can take up to 60 minutes to complete the upgrade process.
Time for a ☕️ ...

" &
}

function jamfHelperNoPower ()
{
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Problem\ Reporter.app/Contents/Resources/ProblemReporter.icns -title "Message from Bauer IT" -heading "No power found - upgrade cannot continue!" -description "Please connect a power cable and try again." -button1 "Retry" -defaultButton 1
}

function jamfHelperNoMADLoginADMissing ()
{
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Problem\ Reporter.app/Contents/Resources/ProblemReporter.icns -title "Message from Bauer IT" -heading "NoMAD Login AD not installed - upgrade cannot continue!" -description "Please contact the IT Service Desk on 0345 058 4444 before attempting this upgrade again." -button1 "Close" -defaultButton 1
}

function jamfHelperMobileAccount ()
{
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Problem\ Reporter.app/Contents/Resources/ProblemReporter.icns -title "Message from Bauer IT" -heading "Mobile account detected - upgrade cannot continue!" -description "To resolve this issue a logout/login is required.

In 30 seconds you will be automatically logged out of your current session.
Please log back in to your Mac, launch the Self Service app and run the ${osName} Upgrade.

If you have any further issues please contact the IT Service Desk on 0345 058 4444." -timeout 30 -button1 "Logout" -defaultButton 1
}

function jamfHelperFVMobileAccounts ()
{
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Problem\ Reporter.app/Contents/Resources/ProblemReporter.icns -title "Message from Bauer IT" -heading "Mobile account detected - upgrade cannot continue!" -description "Please contact the IT Service Desk on 0345 058 4444 before attempting this upgrade again." -button1 "Close" -defaultButton 1
}

function jamfHelperNoSpace ()
{
HELPER_SPACE=$(
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/Problem\ Reporter.app/Contents/Resources/ProblemReporter.icns -title "Message from Bauer IT" -heading "Not enough free space found - upgrade cannot continue!" -description "Please ensure you have at least ${requiredSpace}GB of free space
Available Space : ${freeSpace}Gb

Please delete files and empty your trash to free up additional space.

If you continue to experience this issue, please contact the IT Service Desk on 0345 058 4444." -button1 "Retry" -button2 "Quit" -defaultButton 1
)
}

function addReconOnBoot ()
{
#Check if recon has already been added to the startup script - the startup script gets overwirtten during a jamf manage.
jamfRecon=$(grep "/usr/local/jamf/bin/jamf recon" "/Library/Application Support/JAMF/ManagementFrameworkScripts/StartupScript.sh")
#Check if logout policy has already been added to the startup script - the startup script gets overwirtten during a jamf manage.
jamfLogout=$(grep "/usr/local/jamf/bin/jamf policy -trigger logout" "/Library/Application Support/JAMF/ManagementFrameworkScripts/StartupScript.sh")
if [[ -n "$jamfRecon" ]] && [[ -n "$jamfLogout" ]]; then
  echo "Recon and logout policy already entered in startup script"
else
  #Add recon and logout policy to the startup script
  echo "Recon and logout policy not found in startup script adding..."
  #Remove the exit from the file
  sed -i '' "/$exit 0/d" /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh
  #Add in additional recon line with an exit in
  /bin/echo "## Run Recon and run logout policies" >> /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh
  /bin/echo "/usr/local/jamf/bin/jamf recon" >>  /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh
  /bin/echo "/usr/local/jamf/bin/jamf policy -trigger logout" >>  /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh
  /bin/echo "exit 0" >>  /Library/Application\ Support/JAMF/ManagementFrameworkScripts/StartupScript.sh

    #Re-populate startup script recon check variable
    jamfRecon=$(grep "/usr/local/jamf/bin/jamf recon" "/Library/Application Support/JAMF/ManagementFrameworkScripts/StartupScript.sh")
    jamfLogout=$(grep "/usr/local/jamf/bin/jamf policy -trigger logout" "/Library/Application Support/JAMF/ManagementFrameworkScripts/StartupScript.sh")
    if [[ -n "$jamfRecon" ]] && [[ -n "$jamfLogout" ]]; then
      echo "Recon and logout policy added to the startup script successfully"
    else
      echo "Recon and logout policy NOT added to the startup script"
    fi
fi
}

function checkPower ()
{
##Check if device is on battery or ac power
pwrAdapter=$( /usr/bin/pmset -g ps )
if [[ ${pwrAdapter} =~ "AC Power" ]]; then
	pwrStatus="OK"
	echo "Power Check: OK - AC Power Detected"
else
	pwrStatus="ERROR"
	echo "Power Check: ERROR - No AC Power Detected"
fi
}

function checkSpace ()
{
##Check if free space > 15GB
osMinor=$( /usr/bin/sw_vers -productVersion | awk -F. {'print $2'} )
if [[ $osMinor -eq 12 ]]; then
	freeSpace=$( /usr/sbin/diskutil info / | grep "Available Space" | awk '{print $4}' )
else
  freeSpace=$( /usr/sbin/diskutil info / | grep "Free Space" | awk '{print $4}' )
fi

if [ -z ${freeSpace} ]; then
  freeSpace="5"
fi

if [[ ${freeSpace%.*} -ge ${requiredSpace} ]]; then
	spaceStatus="OK"
	echo "Disk Check: OK - ${freeSpace%.*}GB Free Space Detected"
else
	spaceStatus="ERROR"
	echo "Disk Check: ERROR - ${freeSpace%.*}GB Free Space Detected"
fi
}

function checkNoMADLoginAD()
{
#If a MacBook make sure NoMAD Login AD is installed and the logged in user has a local account
if [[ "$macModel" =~ "MacBook" ]] && [[ "$osShort" -eq "12" ]]; then
  echo "${macModelFull} running ${osFull}, confirming that NoMAD Login AD is installed..."
  if [[ ! -d "$noLoADBundle" ]]; then
    if [[ "$loggedInUser" != "" ]]; then
      echo "NoMAD Login AD not installed, aborting OS Upgrade"
      jamfHelperNoMADLoginADMissing
      exit 1
    else
      echo "NoMAD Login AD not installed, Aborting OS Upgrade"
      exit 1
    fi
  else
    echo "NoMAD Login AD installed"
      if [[ "$loggedInUser" != "" ]]; then
      echo "Confirming that $loggedInUser has a local account..."
        if [[ "$mobileAccount" == "" ]]; then
          echo "$loggedInUser has a local account, carry on with OS Upgrade"
        else
          echo "$loggedInUser has a mobile account, aborting OS Upgrade"
          echo "Advising $loggedInUser via a jamfHelper that they will be logged out in 30 seconds as a logout/login is required"
          jamfHelperMobileAccount
          echo "killing the login session..."
          killall loginwindow
          exit 1
        fi
      else
        fileVaultStatus=$(fdesetup status | sed -n 1p)
          if [[ "$fileVaultStatus" =~ "Off" ]]; then
            echo "FileVault off, carry on with OS upgrade"
          else
            echo "FileVault is on, checking that all FileVault enabled users have local accounts"
            allUsers=$(dscl . -list /Users | grep -v "^_\|casadmin\|daemon\|nobody\|root\|admin")
              for user in $allUsers
                do
                  fileVaultUser=$(fdesetup list | grep "$user" | awk  -F, '{print $1}')
                  if [[ "$fileVaultUser" == "$user" ]]; then
                    fvMobileAccount=$(dscl . read /Users/${user} OriginalNodeName 2>/dev/null)
                      if [[ "$fvMobileAccount" == "" ]]; then
                        echo "$user is a FileVault enabled user with a local account"
                      else
                        echo "$user is a FileVault enabled user with a mobile account, aborting upgrade!"
                        echo "Please contact $user and ask them to login to demobilise their account before attempting the upgrade again"
                        jamfHelperFVMobileAccounts
                        exit 1
                      fi
                  fi
              done
          fi
      fi
    fi
else
  echo "${macModelFull} running ${osFull}, carry on with OS Upgrade"
fi

}

function deleteSleepImage()
{
#Check for a sleepimage and if found delete, this should help with laptops and lack of space as the sleepimage is normally 4-8Gb
if [[ -f /var/vm/sleepimage ]]; then
  echo "sleepimage found deleting..."
  rm -rf /var/vm/sleepimage
    if [[ -f /var/vm/sleepimage ]]; then
      echo "sleepimage NOT deleted!"
    else
      echo "sleepimage DELETED"
    fi
else
  echo "No sleepimage found"
fi
}

function runInstall()
{
#Check if the Mac is a MacBook. If so, make sure NoMAD Login AD is installed
#and that the logged in user has a local account
checkNoMADLoginAD

#Check for Power
checkPower
while ! [[  ${pwrStatus} == "OK" ]]
do
  echo "No Power"
  jamfHelperNoPower
  sleep 5
  checkPower
done

deleteSleepImage

#Check the Mac meets the space Requirements
checkSpace
while ! [[  ${spaceStatus} == "OK" ]]
do
  echo "Not enough Space"
  jamfHelperNoSpace
  if [[ "$HELPER_SPACE" -eq "2" ]]; then
    echo "User clicked quit at lack of space message"
    exit 1
  fi
  sleep 5
  checkSpace
done

echo "Ask for final agreement to upgrade"
jamfHelperUpdateConfirm

echo "--------------------------"
echo "Passed all Checks"
echo "--------------------------"
#Quit all open Apps
echo "Killing all Microsoft Apps to avoid MS Error Reporting launching"
ps -ef | grep Microsoft | grep -v grep | awk '{print $2}' | xargs kill -9
echo "Killing all other open applications for $loggedInUser"
killall -u "$loggedInUser"
#Launch jamfHelper
echo "Launching jamfHelper..."
jamfHelperInProgress
#Begin Upgrade
addReconOnBoot
echo "Removing Pre-Mojave mount network shares content..."
/usr/local/jamf/bin/jamf policy -trigger removemountnetworkshares
echo "Launching startosinstall..."
"$osInstallerLocation"/Contents/Resources/startosinstall --agreetolicense --nointeraction
/bin/sleep 3

exit 0
}

########################################################################
#                         Script starts here                           #
########################################################################

#Clear any jamfHelper windows
killall jamfHelper 2>/dev/null

echo "Starting upgrade to $osName with $osInstallerLocation"
echo "$requiredSpace GB will be required to complete."

#Check the installer is downloaded if it's not there exit
if [[ ! -d "$osInstallerLocation" ]]; then
        echo "No Installer found!"
        echo "Check available disk space and the result of the policy to install macOS Mojave"
        exit 1
else
        echo "Installer found, continuing with upgrade"
fi

if [ "$loggedInUser" == "" ]; then
  echo "No user logged in"
  #Show status of NoLoAD, power and space for reporting. As no user is logged in no action can be taken to fix any issues.
  checkNoMADLoginAD
  checkPower
  deleteSleepImage
  checkSpace
  #Begin Upgrade
  echo "--------------------------"
  echo "Passed all Checks"
  echo "--------------------------"
  echo "Start upgrade"
  addReconOnBoot
  echo "Removing Pre-Mojave mount network shares content..."
  /usr/local/jamf/bin/jamf policy -trigger removemountnetworkshares
  echo "Launching startosinstall..."
  "$osInstallerLocation"/Contents/Resources/startosinstall --nointeraction --agreetolicense
  /bin/sleep 3

  exit 0

else

  echo "Current logged in user is $loggedInUser"
  # Check the value of the timer variable, if greater than 0 i.e. can defer
  # then show a jamfHelper message
  if [[ "$Timer" -gt "0" ]]; then
  echo "User has "$Timer" deferrals left"
  #Launch jamfHelper
  echo "Launching jamfHelper..."
  jamfHelperAsktoUpgrade
  #Get the value of the jamfHelper, user chosing to upgrade now or defer.

    if [[ "$HELPER" -eq "0" ]]; then
          #User chose to ignore
          echo "User clicked no"
          let CurrTimer=$Timer-1
          echo "$CurrTimer" > /Library/Application\ Support/JAMF/.UpgradeDeferral-${policyName}.txt
          exit 0
    else
          #User clicked yes
          echo "User clicked yes"

          #Start the install process
          runInstall

    fi
  fi
fi

# Check the value of the timer variable, if equals 0 then no deferal left run the upgrade

if [[ "$Timer" -eq "0" ]]; then
  echo "No Deferral left, run the install!"
  #Start the install process
  runInstall
fi