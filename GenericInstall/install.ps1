<#
Bastardized easy setup of programs.
Function to check registry
Easy Setup - change variables and go
#>
##############################################################
# Easily changable variables - the names are self explanatory
# Should be a copy and pastable between scripts
# Can add to extraFiles list with ,
# Add extra folder paths to oldInstallPaths list with , 
## to remove after install for legacy clean
##############################################################
#DEBUG switch

$debugout = $false

##############################################################
# Quick and dirty logging

$timeVar = Get-Date -Format HHmmssfff
Start-Transcript -path "C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Staging\JabraDirectInstaller\dbioutput.txt" -append
write-host "version dev6"

##############################################################
# Other Variables

#Enable require requireRunOnEveryLogon if it needs to be a startup item
$requireRunOnEveryLogon = $false
$startupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$altStartupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
$anotherAltStartupList = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"

$nameOfProgram = 'Jabra Direct (32-bit)'
$downloadInstallerPath = 'C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Staging\JabraDirectInstaller'

$installerBackup = $true
$copyInstallerToDirectory = 'C:\Program Files (x86)\Jabra\Direct6'
$exeSetupFile = 'JabraDirectSetup.exe'
$installArguments = '/install /quiet /norestart /log "%WINDIR%\Temp\JabraDirect-Install.log"'

$legacyPathRequireClean = $false
[String[]]$oldInstallPaths = "C:\Win32Apps", "C:\Win32Apps"
[String[]]$extraFiles = 'install.ps1', 'uninstall.ps1', 'JabraDirectInstaller'


############################################################
#Install
############################################################
#Copy Files from package to a local location

New-Item -ItemType Directory -Force -Path $downloadInstallerPath | Out-Null
(New-Object System.Net.WebClient).DownloadFile('https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/JabraDirectSetup.exe', "$downloadInstallerPath\$exeSetupFile") | Start-Process -Wait -FilePath "$downloadInstallerPath\$exeSetupFile" -ArgumentList "$installArguments" -PassThru

foreach ($file in $extraFiles) {
	Copy-Item -Path "$PSScriptRoot\$file" -Destination "$downloadInstallerPath\$file"
}

# Do you need to backup the installer to ensure you can uninstall?
if ($installerBackup) {
	Copy-Item -Path "$downloadInstallerPath\$exeSetupFile" -Destination "$copyInstallerToDirectory\$exeSetupFile"
}

# Have you installed to a legacy location previously and need that cleaned up?
if ($legacyPathRequireClean) {
	foreach ($legacyPath in $oldInstallPaths) {
		try {
		Remove-Item -Path "$legacyPath" -Recurse -Force -Confirm:$false
		}
		catch {
			if($debugout){
				write-host "$legacyPath Old Install Location previously cleaned or wasnt installed"
			}
		}
	}
}

#Create any Powershell scripts required for the program

write-host "Ending Script as a Win"
Stop-Transcript
write-host "0"
Return 877378
