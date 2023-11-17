<#
Bastardized easy setup of programs.
Function to check registry
Easy Setup - change variables and go
#>
############################################################
#Easily changable variables - the names are self explanatory
#Should be a copy and pastable between scripts
#Can add to extraFiles list with ,
############################################################
#DEBUG switch
$debugout = $false
$timeVar = Get-Date -Format HHmmssfff
Start-Transcript -path "C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Staging\DropboxInstaller\dbioutput.txt" -append
write-host "version dev4"
#Enable require requireRunOnEveryLogon if it needs to be a startup item
$requireRunOnEveryLogon = $false
$startupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$altStartupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
$anotherAltStartupList = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
$nameOfProgram = 'Dropbox'
$exeInstallPath = 'C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Staging\DropboxInstaller'
$exeFile = 'DropboxInstaller.exe'
[String[]]$extraFiles = 'install.ps1', 'uninstall.ps1', 'DropboxInstaller'

############################################################
#Install
############################################################
#Copy Files from package to a local location

New-Item -ItemType Directory -Force -Path $exeInstallPath | Out-Null
(New-Object System.Net.WebClient).DownloadFile('https://www.dropbox.com/download?full=1&os=win&arch=x64', "$exeInstallPath\$exeFile") | Start-Process -Wait -FilePath "$exeInstallPath\$exeFile" -ArgumentList '/NOLAUNCH' -PassThru
foreach ($file in $extraFiles) {
	Copy-Item -Path "$PSScriptRoot\$file" -Destination "$exeInstallPath\$file"
}

#Create any Powershell scripts required for the program

Stop-Transcript
Return 0