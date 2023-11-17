<#
Bastardized easy setup of programs.
Function to check registry 
Easy Setup - change variables and go
#>
############################################################
#Easily changable variables - the names are self explanatory
#Should be a copy and pastable field between scripts
#Can add to extraFiles list with , "[File Name/path]
############################################################
#DEBUG switch
$debugout = $false
$timeVar = Get-Date -Format HHmmssfff
Start-Transcript -path "C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Staging\DropboxInstaller\$timeVar dbunoutput.txt" -append
write-host "version dev4"
#Enable require requireRunOnEveryLogon if it needs to be a startup item
$requiredRunOnEveryLogon = $false
$startupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$altStartupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
$anotherAltStartupList = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"

$nameOfProgram = "Dropbox"
$exeInstallPath = "C:\Program Files (x86)\Dropbox\Client"
$exeFile = "DropboxUninstaller.exe"
[String[]]$extraFiles = "install.ps1", "uninstall.ps1"



##################################################################
#Functions
##################################################################


############################################################
#Uninstall
############################################################
#Stop the process for removal

if ($debugout){
	Stop-Process -Name "$nameOfProgram" -Force
	write-host "Stopping $nameOfProgram"
}
Stop-Process -Name "$nameOfProgram" -Force

#Avoid Race conditions interfering between killing all installed tasks and removing paths.
[System.Threading.Thread]::Sleep(10000)


#Outlier Insurance policy - Run twice once from here once from TEMP Insuring self deletion
#-recursive and -force should force the removal but there are some outlier cases where that 
#hasn't happened. The code is split it continues from the ##SPLIT tag.
if ($debugout) {
	Copy-Item -Path .\uninstall.ps1 -Destination $env:TEMP\uninstall.ps1 
}
write-host "Copying Uninstall Script"
Copy-Item -Path .\uninstall.ps1 -Destination $env:TEMP\uninstall.ps1 -ErrorAction SilentlyContinue
Start-Process -Wait -FilePath "$exeInstallPath\$exeFile" -ArgumentList '/InstallType:MACHINE /S' -PassThru
Start-Process -Wait -FilePath "%ProgramFiles%\Dropbox\Client\DropboxUninstaller.exe" -ArgumentList '/InstallType:MACHINE /S' -PassThru
#File and Folder removal.
Remove-Item -Path "$exeInstallPath" -Recurse -Force -Confirm:$false 
Remove-Item $PSCommandPath -Recurse -Force -Confirm:$false 
powershell -File "$env:TEMP\uninstall.ps1" 


##SPLIT - the other bit of the insurance policy
Remove-Item -Path .\uninstall.ps1
Stop-Transcript
Return 0

