#!/bin/bash

########################################################################
#            FileVault deferred enablement forced logout               #
################## Written by Phil Walker July 2019 ####################
########################################################################

#This script is designed to be used with JamfPro and script variables
#when selecting via a policy

########################################################################
#                            Variables                                 #
########################################################################

policyTrigger="$4" #What unique policy trigger actually installs the package
deferralOption1="$5" #deferral time option 1 e.g 0, 300, 3600, 10800 (Now, 5 minutes, 1 hour, 3 hours)
deferralOption2="$6" #deferral time option 2 e.g 0, 300, 3600, 10800 (Now, 5 minutes, 1 hour, 3 hours)
deferralOption3="$7" #deferral time option 3 e.g 0, 300, 3600, 10800 (Now, 5 minutes, 1 hour, 3 hours)
deferralOption4="$8" #deferral time option 4 e.g 0, 300, 3600, 10800 (Now, 5 minutes, 1 hour, 3 hours)

#DEBUG
#policyTrigger="FV2Logout"
#deferralOption1="0"
#deferralOption2="300"
#deferralOption3="1800"
#deferralOption4="3600"

#Get the current logged in user and store in variable
loggedInUser=$(python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

#FileVault deferral status
fv2Deferred=$(fdesetup status | sed -n 2p)

#FileVault enablement deferral username
FV2DeferralUser=$(fdesetup status | sed -n 2p | awk '{print $9}' | cut -d "'" -f2)

#Check if the deferral file exists, if not create, if it does read the value and add to a variable
if [ ! -e /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt ]; then
    touch /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt
else
    deferralTime=$(cat /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt)
    echo "Deferral file present with $deferralTime seconds"
fi
########################################################################
#                            Functions                                 #
########################################################################

function fileVaultDeferral ()
{
#Check if the logged in user matches the FileVault enablement deferal user
if [[ "$fv2Deferred" == "" ]] || [[ "$fv2Deferred" =~ "Encryption in progress" ]]; then
  echo "FileVault enablement not currently deferred, nothing to do"
  exit 0
fi
if [[ "$fv2Deferred" =~ "Deferred" ]] && [[ "$FV2DeferralUser" == "" ]]; then
    echo "FileVault enablement deferred, logout required to start the encryption process"
    echo "The next user to login with be granted a SecureToken and FileVault will be enabled"
elif [[ "$FV2DeferralUser" != "" ]]; then
  if [[ "$loggedInUser" == "$FV2DeferralUser" ]]; then
    echo "Logged in user and FileVault enablement deferral user match, logout required to start the encryption process"
  else
    echo "Logged in user and FileVault enablement deferral user do not match, exiting..."
    exit 0
  fi
fi

}

function jamfHelperFullScreen ()
#Full screen jamfHelper to advise that a logout is required to start the encryption process
{
su - $loggedInUser <<'jamfmsg'
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns -title "Message from Bauer IT" -heading "Disk encryption is waiting to be enabled" -alignHeading center -description "To start the process you must logout of your current session.

Disk encryption is a GDPR requirement for all Bauer MacBooks"  -button1 "ok" defaultbutton "1" -timeout 5 &

jamfmsg
}

function jamfHelperLogoutDeferral ()
#Provide deferral options for the logout with deferral options supplied by the policy
{
HELPER=$(
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns -title "Message from Bauer IT" -heading "Disk encryption is waiting to be enabled" -alignHeading center -description "Please select the most convenient time to logout from the drop down menu.

Make sure to save all of your work as you will be logged out automatically after the time selected has elapsed." -lockHUD -showDelayOptions "$deferralOption1, $deferralOption2, $deferralOption3, $deferralOption4"  -button1 "Select"

)
}

function jamfHelperUpdateDeferralConfirm ()
{
#Advise the user of the selected deferral
#Convert the seconds chosen to human readable days, minutes, hours. No Seconds are calulated
local T=$deferralTime;
local D=$((T/60/60/24));
local H=$((T/60/60%24));
local M=$((T/60%60));
timeChosenHuman=$(printf '%s' "Your current session will be ended in: "; [[ $D > 0 ]] && printf '%d days ' $D; [[ $H -eq 1 ]] && printf '%d hour' $H; [[ $H -ge 2 ]] && printf '%d hours' $H; [[ $M > 0 ]] && printf '%d minutes' $M; [[ $D > 0 || $H > 0 || $M > 0 ]] )
#Show a message via Jamf Helper that the update will be installed after the deferral time chosen
HELPER_DEFERRAL_CONFIRM=$(
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns -title "Message from Bauer IT" -heading "Disk encryption" -description "${timeChosenHuman}" -timeout 10  -button1 "Ok" -defaultButton 1 &
)
}

function jamfHelperLogoutNow ()
{
#Show a message via Jamf Helper that the current login session will be ended in 1 minute
su - $loggedInUser <<'jamfmsg2'
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns -title "Message from Bauer IT" -heading "Disk encryption" -description "The deferral time has now elapsed and your current session will be ended in 1 minute." &
jamfmsg2
}

function performLogout ()
{

#Kill the deferal file before the login session is ended
rm /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt
if [ -e /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt ]; then
    echo "Something went wrong, the deferral timer file is still present"
else
    echo "Deferral file removed after the policy was triggered"
fi

#Call the policy to force a logout
/usr/local/jamf/bin/jamf policy -trigger $policyTrigger

}


########################################################################
#                         Script starts here                           #
########################################################################

if [ "$loggedInUser" == "" ]; then
    echo "No logged in user, nothing to do"
  else
    fileVaultDeferral
    jamfHelperFullScreen
    sleep 30s
    killall jamfHelper
    #Read the deferral time from the file, incase Mac got rebooted. This will determine the next step
    deferralTime=$(cat /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt)

    if [[ -z $deferralTime ]]; then #No Deferral time set so we can now ask the user to set one
      echo "$loggedInUser now being asked to select a convenient time to logout. Following options available $deferralOption1, $deferralOption2, $deferralOption3, $deferralOption4 "
      #Run function to show jamf Helper message to ask user to set deferral time
      jamfHelperLogoutDeferral
      #Format the dropdown result from JamfHlper as a 1 gets added at the end when the button is pressed
      timeChosen="${HELPER%?}"
      #Save the selected deferral time to a text file and then add to the variable
      echo "$timeChosen" > /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt
      deferralTime=$(cat /Library/Application\ Support/JAMF/.Deferral-${policyTrigger}.txt)

      if [ "$HELPER" == "1" ]; then #Option1 is always 0 seconds so no deferral
          echo "$deferralOption1 selected logout now"
          performLogout

      else # A deferral time was selected from the dropdown menu, show user what was selected
        jamfHelperUpdateDeferralConfirm #Message auto closes after 10 seconds
        echo "Wait for $deferralTime before running $policyTrigger"
        sleep $deferralTime
          #Confirm session will be ended in 1 minute
          jamfHelperLogoutNow
          sleep 60s
            performLogout
        fi
    else # A deferral time has already been set and saved in the .Deferral-${policyTrigger}.txt file
      echo "$loggedInUser already has a deferal time set of $deferralTime, wait for deferral time then ask to apply update"
      echo "Wait for $deferralTime before running $policyTrigger"
      sleep $deferralTime
        #Confirm session will be ended in 1 minute
        jamfHelperLogoutNow
        sleep 60s
          performLogout
    fi
fi
