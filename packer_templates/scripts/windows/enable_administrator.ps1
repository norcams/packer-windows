# Final cleanup - prepare for OpenStack

# Disable winrm
#Disable-PSRemoting -Force
#Disable-PSSessionConfiguration
#Set-Service WinRM -StartupType Disabled -PassThru

# Remove the vagrant user
#Remove-LocalUser -Name "Vagrant"

## Configure and run sysprep
#  $unattend = @'
#<?xml version="1.0" encoding="utf-8"?>
#<unattend xmlns="urn:schemas-microsoft-com:unattend">
#    <servicing></servicing>
#    <settings pass="oobeSystem">
#        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#            <OOBE>
#                <HideEULAPage>true</HideEULAPage>
#                <SkipUserOOBE>true</SkipUserOOBE>
#                <HideLocalAccountScreen>true</HideLocalAccountScreen>
#            </OOBE>
#        </component>
#        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#            <InputLocale>no-nb</InputLocale>
#            <SystemLocale>no-nb</SystemLocale>
#            <UserLocale>no-nb</UserLocale>
#        </component>
#    </settings>
#</unattend>
#'@
#$unattend | Out-File "c:\windows\system32\sysprep\unattend.xml" -encoding utf8

#[System.Threading.Timeout]::InfiniteTimeSpan

##c:\windows\system32\sysprep\Sysprep /generalize /oobe /quit /unattend:c:\windows\system32\sysprep\unattend.xml
#Write-Host 'Running Sysprep...'
#$unattendedXmlPath = "c:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
#c:\windows\system32\sysprep\Sysprep /generalize /oobe /quit /unattend:"$unattendedXmlPath"

#Start-Sleep -Seconds 10

#$content = get-content "C:\windows\system32\sysprep\Panther\setupact.log"
#write-host $content
#write-host "Error log file:"
#$content = get-content "C:\windows\system32\sysprep\Panther\setuperr.log"
#write-host $content

## Set local administrator password as we need the account for final cleanup and sysprep.
## The administrator account will be disabled by cloudbase-init after boot.
#$Password = ConvertTo-SecureString "P@sssW0rD!" -AsPlainText -Force
#$UserAccount = Get-LocalUser -Name "Administrator"
#$UserAccount | Set-LocalUser -Password $Password
