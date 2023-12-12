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
Start-Transcript -path "C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Staging\DropboxInstaller\$timeVar dbunoutput.txt" -append
write-host "version dev5"

##############################################################
# Other Variables

#Enable require requireRunOnEveryLogon if it needed to be a startup item and needs to be removed

$requiredRunOnEveryLogon = $false
$startupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$altStartupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
$anotherAltStartupList = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"

$nameOfProgram = "Jabra Direct (32-bit)"
$otherProcessKillRequired = $true
[String[]]$otherProcesses = "jabra-direct", "SoftphoneIntegrations"

$useInstallerToUninstall = $true
$installerBackup = 'C:\Program Files (x86)\Jabra\Direct6'
$exeInstallPath = 'C:\Program Files (x86)\Jabra\'
$downloadInstallerPath = 'C:\Program Files (x86)\Jabra\Direct6'

$extraPathRemoval = $true
[String[]]$pathsToRemove = "C:\Program Files (x86)\Jabra\Direct6", "C:\Program Files (x86)\Jabra\Drivers", "C:\Program Files (x86)\Jabra"

$exeUninstallFile = 'JabraDirectSetup.exe'
$uninstallArguments = '/uninstall /quiet /norestart /log "%WINDIR%\Temp\JabraDirect-Uninstall.log"'
[String[]]$extraFiles = "install.ps1", "uninstall.ps1"


##################################################################
#Functions
##################################################################
#Empty


############################################################
#Uninstall
############################################################
#Stop the process for removal

if ($debugout){
	try {
		Stop-Process -Name "$nameOfProgram" -Force
		write-host "Stopping $nameOfProgram"
	}
	catch {
		write-host "No Process named $nameOfProgram to Kill"
	}
}

try {
Stop-Process -Name "$nameOfProgram" -Force
}
catch {
	write-host "No Process named $nameOfProgram to Kill"
}

if ($otherProcessKillRequired) {
	foreach ($processToKill in $otherProcessKillRequired) {
		try {
		Stop-Process -Name "$processToKill" -Force
		}
		catch {
			if($debugout){
				write-host "$processToKill process was either already killed or didnt exist"
			}
		}
	}
}

#Avoid Race conditions interfering between killing all installed tasks and removing paths.
[System.Threading.Thread]::Sleep(10000)


#Outlier Insurance policy - Run twice once from here once from TEMP Insuring self deletion
#-recursive and -force should force the removal but there are some outlier cases where that 
#hasn't happened. The code is split it continues from the ##SPLIT tag.

write-host "Copying Uninstall Script"
try {
	Copy-Item -Path .\uninstall.ps1 -Destination $env:TEMP\uninstall.ps1 -ErrorAction SilentlyContinue
}
catch {
	write-host "Something may have gone wrong if it did this on first instance - Otherwise all is good"
}

##########################################################################################
# Uninstall Process
# be sure to leave the actual uninstall process out of a try catch so you can debug if
# something goes wrong and intune metrics line up.

if ([System.IO.File]::Exists("$installerBackup\$exeUninstallFile"){
	Start-Process -Wait -FilePath "$installerBackup\$exeUninstallFile" -ArgumentList "$uninstallArguments" -PassThru
}
else {
	(New-Object System.Net.WebClient).DownloadFile('https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/JabraDirectSetup.exe', "$downloadInstallerPath\$exeUninstallFile") | Start-Process -Wait -FilePath "$downloadInstallerPath\$exeUninstallFile" -ArgumentList "$uninstallArguments" -PassThru
}


#File and Folder removal.
if ($extraPathRemoval) {
	foreach ($path in $pathsToRemove) {
		try {
			Remove-Item -Path "$path" -Recurse -Force -Confirm:$false
		}
		catch {
			if($debugout){
				write-host "$path Old Install Location previously cleaned or wasnt installed"
			}
		}
	}
}

try {
Remove-Item -Path "$exeInstallPath" -Recurse -Force -Confirm:$false 
}
catch {
	write-host "Application Install didnt exist in updated path"
}

try {
Remove-Item $PSCommandPath -Recurse -Force -Confirm:$false 
}
catch {
	write-host "failed to remove initial run path there is a backup clearing process that will run shortly"
}

try {
powershell -File "$env:TEMP\uninstall.ps1" 
}
catch {
	write-host "backup removal routine already cleared final run"
}
##SPLIT - the other bit of the insurance policy
try {
Remove-Item -Path .\uninstall.ps1
Remove-Item -Path "$env:TEMP\uninstall.ps1" 
}
catch {
	write-host "already removed last trace off disk - only running in memory"
}
try {
Remove-Item -Path "$env:TEMP\uninstall.ps1" 
}
catch {
	write-host "Extra Clean Redundancy"
}
write-host "Successfully finished - Stopping Transcription of Process"
write-host "Ending Script as a Win"
Stop-Transcript
write-host "0"
Return 877378



