# Only allow RDP connection from specific CIDR ranges
$ips = @("129.240.0.0/16", "129.177.0.0/16", "2001:700:100::/48", "2001:700:200::/48")
Set-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)" -Direction Inbound -Protocol TCP -RemoteAddress $ips -Action Allow
Set-NetFirewallRule -DisplayName "Remote Desktop - User Mode (UDP-In)" -Direction Inbound -Protocol UDP -RemoteAddress $ips -Action Allow

# Enable NLA for RDP
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -Name “UserAuthentication” -Value 1

# Disable IPv6 transition technologies
Set-Net6to4Configuration -State disabled
Set-NetTeredoConfiguration -Type disabled
Set-NetIsatapConfiguration -State disabled

# Disable IPv6 Router autoconfig
Set-NetIPInterface ethernet -AddressFamily ipv6 -RouterDiscovery Disabled

# Enable ping (ICMP Echo Request on IPv4 and IPv6)
netsh advfirewall firewall set rule name = "File and Printer Sharing (Echo Request - ICMPv4-In)" new enable=yes
netsh advfirewall firewall set rule name = "File and Printer Sharing (Echo Request - ICMPv6-In)" new enable=yes

# Disable Network discovery
netsh advfirewall firewall set rule group = "Network Discovery" new enable=No

# Set correct timezone
Set-TimeZone -Id "W. Europe Standard Time"

# Set local ntp servers as external servers may be unreachable due to firewalling
w32tm /config /manualpeerlist:"ntp1.uio.no ntp2.uio.no" /syncfromflags:manual /update

# Set fancy NREC wallpaper
$wallpaper = "c:\Users\vagrant\Wallpaper.jpg"
if(Test-Path $wallpaper)
{
    $Host.UI.RawUI.WindowTitle = "Configuring wallpaper..."

    # Put the wallpaper in place
    $wallpaper_dir = "$ENV:SystemRoot\web\Wallpaper\Cloudbase"
    if (!(Test-Path $wallpaper_dir))
    {
        mkdir $wallpaper_dir
    }

    copy "$wallpaper" "$wallpaper_dir\Wallpaper-Cloudbase-2013.jpg"
    $gpoZipPath = "c:\Users\vagrant\GPO.zip"
    foreach($item in (New-Object -com shell.application).NameSpace($gpoZipPath).Items())
    {
        $yesToAll = 16
        (New-Object -com shell.application).NameSpace("$ENV:SystemRoot\System32\GroupPolicy").copyhere($item, $yesToAll)
    }
}

# Remove Azure Arc Setup
$OSVersion = (get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
Write-Host "Removing AzureArcSetup"
If($OSVersion -eq "Windows Server 2022 Standard") {
  Remove-WindowsFeature AzureArcSetup
  Write-Host "Azure Arc Setup was removed"
  }
ElseIf ($winbuild -ge 26100) {
  DISM /online /Remove-Capability /CapabilityName:AzureArcSetup~~~~ /NoRestart
  Write-Host "Azure Arc Setup was removed"
}

# Download Firefox and install it
try {
  Write-Host "Downlad Firefox and install it"
  $SourceURL = "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US";
  $Installer = $env:TEMP + "\firefox.msi";
  Set-Variable ProgressPreference SilentlyContinue ; Invoke-WebRequest -URI $SourceURL -OutFile $Installer;
  Start-Process msiexec.exe -Wait -ArgumentList "/I $Installer /quiet"
  }
catch {
   $message = "Tried to install with result $LASTEXITCODE"
   Write-warning $message
   CONTINUE
}

# Remove Edge
try {
  Write-Host 'Disable later autoinstall of MS Edge...'
  New-Item -Path 'HKLM:\Software\Microsoft' -Name 'EdgeUpdate' -Force
  Set-ItemProperty -Path 'HKLM:\Software\Microsoft\EdgeUpdate' -Name DoNotUpdateToEdgeWithChromium -Value 1
}
catch {
  $message = "Disable autoinstall of MS Edge with result $LASTEXITCODE"
  Write-warning $message
  CONTINUE
}
try {
  Write-Host "Remove Edge web browser"
  & 'c:\Program Files (x86)\Microsoft\Edge\Application\*\Installer\setup.exe' -uninstall -system-level -verbose-logging -force-uninstall
}
catch {
  $message = "Tried to remove Edge with result $LASTEXITCODE"
  Write-warning $message
  CONTINUE
}

Write-Host "Enable Build-In Component Cleanup for weekly execution"
$trigger = New-ScheduledTaskTrigger -Weekly -AT "03:00" -DaysOfWeek 'Saturday' -RandomDelay (New-TimeSpan -Hours 4)
Set-ScheduledTask -TaskName "\Microsoft\Windows\Servicing\StartComponentCleanup" -Trigger $trigger
Enable-ScheduledTask -TaskName "\Microsoft\Windows\Servicing\StartComponentCleanup"

Write-Host "Create and enable a task for some housecleaning"
$trigger2 = New-ScheduledTaskTrigger -Weekly -AT "03:00" -DaysOfWeek 'Thursday' -RandomDelay (New-TimeSpan -Hours 3)
$STPrin = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
$Stask = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "c:\windows\cleanup.ps1"
Register-ScheduledTask Cleanup -Action $Stask -Principal $STPrin -Trigger $trigger2

Write-Host "Disable startup of Server Manager on Logon on non-core installs"
try {
  Disable-ScheduledTask -TaskName "\Microsoft\Windows\Server Manager\ServerManager"
}
catch {
  $message = "Tried to disable ServerManager with result $LASTEXITCODE"
  Write-warning $message
  CONTINUE
}

  $startuptask = @'
# Disable Administrator Account
Disable-LocalUser -Name "Administrator"

# Force the local interface to use the "public" profile
Set-NetConnectionProfile -Name "Network" -NetworkCategory Public

$kmsserver="p1-lic01.uib.no"
$nettest=(Test-NetConnection -ComputerName $kmsserver -Port 1688)
if ($nettest.TcpTestSucceeded -eq $true)
  {Write-Host "Connection to kms host succesful - trying to activate windows."
  cscript c:\windows\system32\slmgr.vbs /skms $kmsserver
  cscript c:\windows\system32\slmgr.vbs /ato }
Else {Write-Host "Connection to kms host failed - not activating."}

# Enable and start ssh if Windows Version is 2019 or newer
# Comment out two lines in default sshd_config to enable passwordless logon
$winbuild=$([System.Environment]::OSVersion.Version.Build)
if ($winbuild -gt 17760) {
  Write-Host "Build is 2019 or newer"
  if ($winbuild -le 26100) {
    Write-Host "Build older than 2025"
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
  }
  Set-Service sshd -StartupType Automatic
  Set-Service ssh-agent -StartupType Automatic
  Start-Service sshd
  Start-Service ssh-agent
  $line = Get-Content "C:\ProgramData\ssh\sshd_config" | Select-String "Match Group administrators" | Select-Object -ExpandProperty Line
  $line2 = Get-Content "C:\ProgramData\ssh\sshd_config" | Select-String "AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators" | Select-Object -ExpandProperty Line
  $sshconfig = Get-Content "C:\ProgramData\ssh\sshd_config"
  $sshconfig | ForEach-Object {$_ -replace $line,"#Match Group administrators"} | Set-Content "C:\ProgramData\ssh\sshd_config"
  $sshconfig = Get-Content "C:\ProgramData\ssh\sshd_config"
  $sshconfig | ForEach-Object {$_ -replace $line2,"#       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys"} | Set-Content "C:\ProgramData\ssh\sshd_config"
  if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
  } else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
  }
  if ($winbuild -ge 26100) {
    Write-Host "Allow SSH from everywhere"
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Profile Public,Private,Domain
  }
  Restart-Service sshd
  }
Else {Write-Host "Build is to old for ssh server"}
'@
$startuptask | Out-File "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\extraconf.ps1"

  $mytask = @'
Function Cleanup { 
<# 
.CREATED BY: 
    Matthew A. Kerfoot 
.CREATED ON: 
    10\17\2013 
.Synopsis 
   Aautomate cleaning up a C: drive with low disk space 
.DESCRIPTION 
   Cleans the C: drive's Window Temperary files, Windows SoftwareDistribution folder, ` 
   the local users Temperary folder, IIS logs(if applicable) and empties the recycling bin. ` 
   All deleted files will go into a log transcript in C:\Windows\Temp\. By default this ` 
   script leaves files that are newer than 7 days old however this variable can be edited. 
.EXAMPLE 
   PS C:\Users\mkerfoot\Desktop\Powershell> .\cleanup_log.ps1 
   Save the file to your desktop with a .PS1 extention and run the file from an elavated PowerShell prompt. 
.NOTES 
   This script will typically clean up anywhere from 1GB up to 15GB of space from a C: drive. 
.FUNCTIONALITY 
   PowerShell v3 
#> 
function global:Write-Verbose ( [string]$Message ) 
 
# check $VerbosePreference variable, and turns -Verbose on 
{ if ( $VerbosePreference -ne 'SilentlyContinue' ) 
{ Write-Host " $Message" -ForegroundColor 'Yellow' } } 
 
$VerbosePreference = "Continue" 
$DaysToDelete = 1 
$LogDate = get-date -format "MM-d-yy-HH" 
$objShell = New-Object -ComObject Shell.Application  
$objFolder = $objShell.Namespace(0xA) 
$ErrorActionPreference = "silentlycontinue" 
                     
Start-Transcript -Path C:\Windows\Temp\$LogDate.log 
 
## Cleans all code off of the screen. 
Clear-Host 
 
$size = Get-ChildItem C:\Users\* -Include *.iso, *.vhd -Recurse -ErrorAction SilentlyContinue |  
Sort Length -Descending |  
Select-Object Name, 
@{Name="Size (GB)";Expression={ "{0:N2}" -f ($_.Length / 1GB) }}, Directory | 
Format-Table -AutoSize | Out-String 
 
$Before = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName, 
@{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } }, 
@{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}}, 
@{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } }, 
@{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } | 
Format-Table -AutoSize | Out-String                       
                     
## Stops the windows update service.  
Get-Service -Name wuauserv | Stop-Service -Force -Verbose -ErrorAction SilentlyContinue 
## Windows Update Service has been stopped successfully! 
 
## Deletes the contents of windows software distribution. 
Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue | remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue 
## The Contents of Windows SoftwareDistribution have been removed successfully! 
 
## Deletes the contents of the Windows Temp folder. 
Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue | 
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete)) } | 
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue 
## The Contents of Windows Temp have been removed successfully! 
              
## Delets all files and folders in user's Temp folder.  
Get-ChildItem "C:\users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | 
Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-$DaysToDelete))} | 
remove-item -force -Verbose -recurse -ErrorAction SilentlyContinue 
## The contents of C:\users\$env:USERNAME\AppData\Local\Temp\ have been removed successfully! 
                     
## Remove all files and folders in user's Temporary Internet Files.  
Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" ` 
-Recurse -Force -Verbose -ErrorAction SilentlyContinue | 
Where-Object {($_.CreationTime -le $(Get-Date).AddDays(-$DaysToDelete))} | 
remove-item -force -recurse -ErrorAction SilentlyContinue 
## All Temporary Internet Files have been removed successfully! 
                     
## Cleans IIS Logs if applicable. 
Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue | 
Where-Object { ($_.CreationTime -le $(Get-Date).AddDays(-60)) } | 
Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue 
## All IIS Logfiles over x days old have been removed Successfully! 
                   
## deletes the contents of the recycling Bin. 
## The Recycling Bin is now being emptied! 
$objFolder.items() | ForEach-Object { Remove-Item $_.path -ErrorAction Ignore -Force -Verbose -Recurse } 
## The Recycling Bin has been emptied! 
 
## Starts the Windows Update Service 
##Get-Service -Name wuauserv | Start-Service -Verbose 
 
$After =  Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName, 
@{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } }, 
@{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f( $_.Size / 1gb)}}, 
@{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) } }, 
@{ Name = "PercentFree" ; Expression = {"{0:P1}" -f( $_.FreeSpace / $_.Size ) } } | 
Format-Table -AutoSize | Out-String 
 
## Sends some before and after info for ticketing purposes 
 
Hostname ; Get-Date | Select-Object DateTime 
Write-Verbose "Before: $Before" 
Write-Verbose "After: $After" 
Write-Verbose $size 
## Completed Successfully! 
Stop-Transcript } Cleanup
'@
$mytask | Out-File c:\windows\cleanup.ps1

  # Create and enable a task for block discard via SCSI_UNMAP
  $defragtask = New-ScheduledTaskAction -Execute "defrag.exe" -Argument "/C /L"
  $STPrin = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $trigger3 = New-ScheduledTaskTrigger -Weekly -AT "03:00" -DaysOfWeek 'Sunday' -RandomDelay (New-TimeSpan -Hours 3)
  Register-ScheduledTask BlockDiscard -Action $defragtask -Principal $STPrin -Trigger $trigger3

  # Create and enable a task for NREC reporting
  $trigger4 = New-ScheduledTaskTrigger -Once -AT 04:00 -RandomDelay (New-TimeSpan -Hours 3) -RepetitionInterval (New-TimeSpan -Hours 12)
  $STPrin = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
  $Stask = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "c:\windows\nrecdownload.ps1"
  Register-ScheduledTask "NREC reporting" -Action $Stask -Principal $STPrin -Trigger $trigger4

  $mytask2 = @'
##############################################
#
# Download report script and execute.
#
# From the NREC team.
#
##############################################

$outputfile = "c:\windows\nrecreport.ps1"
$osversion  = (Get-WmiObject -class Win32_OperatingSystem).Caption -replace ' ','_'
$url        = "https://report.nrec.no/downloads/windows/" + $osversion + "/v1/report"

# Remove old script and create empty file
If (Test-Path $outputfile){
    Remove-Item $outputfile
}
New-Item $outputfile -ItemType file

# Download new script from NREC
Invoke-WebRequest -Uri $url -OutFile $outputfile

# Whitelist downloaded script for execution
Unblock-File -Path $outputfile

# Execute the script file
$result = Invoke-Expression $outputfile

#Write-Output $result
'@
$mytask2 | Out-File c:\windows\nrecdownload.ps1

Exit 0
