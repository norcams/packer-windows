#
# Download and install Cloudbase-init
#

$resourcesDir = "c:\windows\temp"
#$CloudbaseInitConfigPath = "$resourcesDir\cloudbase-init.conf"

function Write-Log {
    Param($messageToOut)
    Write-Host ("{0} - {1}" -f @((Get-Date), $messageToOut))
}

function Execute-Retry {
    Param(
	[parameter(Mandatory=$true)]
        $command,
        [int]$maxRetryCount=4,
        [int]$retryInterval=4
    )

    $currErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $retryCount = 0
    while ($true) {
        try {
            $res = Invoke-Command -ScriptBlock $command
            $ErrorActionPreference = $currErrorActionPreference
            return $res
        } catch [System.Exception] {
            $retryCount++
            if ($retryCount -ge $maxRetryCount) {
                $ErrorActionPreference = $currErrorActionPreference
                throw
            } else {
                if($_) {
                    Write-Warning $_
                }
                Start-Sleep $retryInterval
            }
	}
    }
}

function Download-CloudbaseInit {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$resourcesDir,
        [Parameter(Mandatory=$false)]
        [string]$osArch,
        [parameter(Mandatory=$false)]
        [switch]$BetaRelease,
        [parameter(Mandatory=$false)]
        [string]$MsiPath,
        [string]$CloudbaseInitConfigPath,
        [string]$CloudbaseInitUnattendedConfigPath
    )
    $CloudbaseInitMsiPath = "$resourcesDir\CloudbaseInit.msi"
    if ($CloudbaseInitConfigPath) {
        Write-Log "Copying Cloudbase-Init custom configuration fi$CloudbaseInitConfigPath = "$resourcesDir\cloudbase-init.conf"\cloudbase-init.conf"
    }
    if ($CloudbaseInitUnattendedConfigPath) {
        Write-Log "Copying Cloudbase-Init custom unattended configuration file..."
        Copy-Item -Force $CloudbaseInitUnattendedConfigPath `
            "$resourcesDir\cloudbase-init-unattend.conf"
    }

    if ($MsiPath) {
        if (!(Test-Path $MsiPath)) {
            throw "Cloudbase-Init installer could not be copied. $MsiPath does not exist."
        }
        Write-Log "Copying Cloudbase-Init..."
        Copy-Item $MsiPath $CloudbaseInitMsiPath
        return
    }
    Write-Log "Downloading Cloudbase-Init..."
#    $msiBuildArchMap = @{
#        "amd64" = "x64"
#        "i386" = "x86"
#        "x86" = "x86"
#    }
    $msiBuildSuffix = ""
    if (-not $BetaRelease) {
        $msiBuildSuffix = "_Stable"
    }
    $CloudbaseInitMsi = "CloudbaseInitSetup{0}_x64.msi" -f @($msiBuildSuffix)
    $CloudbaseInitMsiUrl = "https://www.cloudbase.it/downloads/$CloudbaseInitMsi"

    Execute-Retry {
        (New-Object System.Net.WebClient).DownloadFile($CloudbaseInitMsiUrl, $CloudbaseInitMsiPath)
    }
}

$Host.UI.RawUI.WindowTitle = "Downloading Cloudbase-Init..."
Download-CloudbaseInit -resourcesDir $resourcesDir

$Host.UI.RawUI.WindowTitle = "Installing Cloudbase-Init..."

$cloudbaseInitInstallDir = Join-Path $ENV:ProgramFiles "Cloudbase Solutions\Cloudbase-Init"
$CloudbaseInitMsiPath = "$resourcesDir\CloudbaseInit.msi"
$CloudbaseInitConfigPath = "$resourcesDir\cloudbase-init.conf"
$CloudbaseInitUnattendedConfigPath = "$resourcesDir\cloudbase-init-unattend.conf"
$CloudbaseInitMsiLog = "$resourcesDir\CloudbaseInit.log"

if (!$serialPortName) {
    $serialPorts = Get-WmiObject Win32_SerialPort
    if ($serialPorts) {
        $serialPortName = $serialPorts[0].DeviceID
    }
}

$msiexecArgumentList = "/i $CloudbaseInitMsiPath /qn /l*v $CloudbaseInitMsiLog"
if ($serialPortName) {
    $msiexecArgumentList += " LOGGINGSERIALPORTNAME=$serialPortName"
}

$cloudbaseInitUser = 'cloudbase-init'
if ($runCloudbaseInitUnderLocalSystem) {
    $msiexecArgumentList += " RUN_SERVICE_AS_LOCAL_SYSTEM=1"
    $cloudbaseInitUser = "LocalSystem"
}

$p = Start-Process -Wait -PassThru -FilePath msiexec -ArgumentList $msiexecArgumentList
if ($p.ExitCode -ne 0) {
    Write-Log "Cloudbase-Init" "Failed to install cloudbase-init"
    throw "Installing $CloudbaseInitMsiPath failed. Log: $CloudbaseInitMsiLog"
}

if (Test-Path $CloudbaseInitConfigPath) {
    Copy-Item -Force $CloudbaseInitConfigPath "${cloudbaseInitInstallDir}\conf\cloudbase-init.conf"
    Write-Log "CustomCloudbaseInitConfig" $CloudbaseInitConfigPath
}
if (Test-Path $CloudbaseInitUnattendedConfigPath) {
    Copy-Item -Force $CloudbaseInitUnattendedConfigPath "${cloudbaseInitInstallDir}\conf\cloudbase-init-unattend.conf"
    Write-Log "CustomCloudbaseInitUnattendConfig" $CloudbaseInitUnattendedConfigPath
}

if (!$setCloudbaseInitDelayedStart) {
    Write-Log "Cloudbase-InitSetupComplete" "Cloudbase-Init service set to start using SetupComplete"
    & "${cloudbaseInitInstallDir}\bin\SetSetupComplete.cmd"
} else {
    cmd /c "sc config cloudbase-init start= delayed-auto"
    if ($LASTEXITCODE) {
        throw "Cloudbase-Init service startup type could not be set to delayed-auto"
    }
    Write-Log "Cloudbase-InitDelayedStart" "Cloudbase-Init service startup type set to delayed-auto"
}
Write-Log "Cloudbase-Init" "Service installed successfully under user ${cloudbaseInitUser}"
