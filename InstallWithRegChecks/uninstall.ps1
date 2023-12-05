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
Start-Transcript -path "$env:TEMP\$timeVar diUnoutput.txt" -append
write-host "version dev3"
#Enable require requireRunOnEveryLogon if it needs to be a startup item
$requiredRunOnEveryLogon = $true
$startupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$altStartupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
$anotherAltStartupList = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"

$nameOfProgram = "DesktopInfo64"
$exeInstallPath = "C:\Program Files (x86)\Win32Apps"
$exeInstallPath2 = "C:\Win32Apps"
$exeFile = "DesktopInfo64.exe"
[String[]]$extraFiles = "DesktopInfo64W.exe", "desktopinfo.ini", "libeay32.dll",`
						"ssleay32.dll", "GetCellularIP.ps1", "GetEthernetIP.ps1",`
						"GetWifiIP.ps1"



##################################################################
#Functions
##################################################################

function regExistCheck { 
	param ($regExpectedPath,$regExpectedValueName = "Not Entered",$regExpectedValueData = "Not Entered")
	#param filter
	$enteredValueName = $regExpectedValueName -ne "Not Entered"
	$enteredValueData = $regExpectedValueData -ne "Not Entered"
	#DEBUG switch
	$debugout = $true
	
	
	#check path
	$regKeyExists = Test-Path -Path "$regExpectedPath"
	if ($debugout) {
		write-host "Variable While checking for Reg Path"
		write-host "regExpectedPath: $regExpectedPath"
		write-host "regExpectedValueName: $regExpectedValueName"
		write-host "regExpectedValueData: $regExpectedValueData"
		write-host "enteredValueName: $enteredValueName"
		write-host "enteredValueData: $enteredValueData"
		write-host "regKeyExists: $regKeyExists"
	}
	
	if (-not $regKeyExists){
		write-host "Path and Key doesn't exist"
		return "keyMissing"
	}
	
	write-host "Variable While checking for Reg Path"
	if(-not $enteredValueName){
		write-host "Only checked if path exists"
		return "exists"
	}
	if ($debugout) {
		write-host "path checked"
		write-host "regExpectedValueName: $regExpectedValueName"
	}
	
	#check value name
	$regEntryExists = Get-ItemProperty -Path "$regExpectedPath" -Name "$regExpectedValueName"
	if ($debugout){
		write-host "regEntryExists: $regEntryExists"
	}
	if (-not $regEntryExists){
		write-host "Value doesn't exist"
		return "valueMissing"
	}
	if(-not $enteredValueData){
		write-host "Didn't enter data value - So only checked Path and Value Name"
		return "exists"
	}
	
	if ($debugout) {
		write-host "value name checked"
	} 
	
	#check value data
	$currentRegValue = Get-ItemProperty -Path $regExpectedPath | Select-Object -ExpandProperty $regExpectedValueName
	if ($debugout) {
		write-host "current reg value var: $currentRegValue"
		write-host "regExpectedValueData: $regExpectedValueData"
		write-host "current reg value loaded"
	}
	if ("$currentRegValue" -ne "$regExpectedValueData"){
		write-host "Expected reg value data didn't match"
		return "dataMissing"
	}
	if ($debugout){
		write-host "value data checked"
	}
	return "exists"		
}




############################################################
#variables with quick checks - Processed Variables
############################################################
if($requiredRunOnEveryLogon){
	$altValueData = "2 0 0 0 0 0 0 0 0 0 0 0"
	$preJoinedValueData = [string]::Join('\',$exeInstallPath,$exeFile)
	$preJoinedValueData2 = [string]::Join('\',$exeInstallPath2,$exeFile)
	$checkIfRegExists = regExistCheck -regExpectedPath "$startupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$preJoinedValueData"
	$checkIfAltRegExists = regExistCheck -regExpectedPath "$altStartupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$altValueData"
	$checkIfAnotherAltRegExists = regExistCheck -regExpectedPath "$anotherAltStartupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$preJoinedValueData"
	$checkIfRegExists2 = regExistCheck -regExpectedPath "$startupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$preJoinedValueData2"
	$checkIfAltRegExists2 = regExistCheck -regExpectedPath "$altStartupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$altValueData"
	$checkIfAnotherAltRegExists2 = regExistCheck -regExpectedPath "$anotherAltStartupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$preJoinedValueData2"
	
	
	$regExist = "$checkIfRegExists" -eq "exists"
	$altRegExist = "$checkIfAltRegExists" -eq "exists"
	$anotherAltRegExist = "checkIfAnotherAltRegExists" -eq "exists"
	$regExist2 = "$checkIfRegExists2" -eq "exists"
	$altRegExist2 = "$checkIfAltRegExists2" -eq "exists"
	$anotherAltRegExist2 = "checkIfAnotherAltRegExists2" -eq "exists"


	if ($debugout){
		write-host "Variable Checkpoint"
		write-host "preJoinedValueData: $preJoinedValueData"
		write-host "checkIfRegExists: $checkIfRegExists"
		write-host "checkIfAltRegExists: $checkIfAltRegExists"
		write-host "checkIfAnotherAltRegExists = $checkIfAnotherAltRegExists"
		write-host "preJoinedValueData2: $preJoinedValueData2"
		write-host "checkIfRegExists2: $checkIfRegExists2"
		write-host "checkIfAltRegExists2: $checkIfAltRegExists2"
		write-host "checkIfAnotherAltRegExists2 = $checkIfAnotherAltRegExists2"
		write-host "  "
		write-host "regExist: $regExist"
		write-host "altRegExist: $altRegExist"
		write-host "anotherAltRegExist: $anotherAltRegExist"
		write-host "regExist2: $regExist2"
		write-host "altRegExist2: $altRegExist2"
		write-host "anotherAltRegExist2: $anotherAltRegExist2"
		write-host "  "
write-host "=============="
	}
}



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


#Reg Removal
if($requiredRunOnEveryLogon){
	if ($debugout){
		write-host "startup list $startupList"
		write-host "name of program: $nameOfProgram"
		write-host "regExist: $regExist"
		write-host "altRegExist: $altRegExist"
		write-host "anotherAltRegExist: $anotherAltRegExist"
		write-host "regExist2: $regExist2"
		write-host "altRegExist2: $altRegExist2"
		write-host "anotherAltRegExist2: $anotherAltRegExist2"
		Get-ItemProperty -Path "$startupList" -Name "$nameOfProgram"
		Get-ItemProperty -Path "$altStartupList" -Name "$nameOfProgram"
		Get-ItemProperty -Path "$anotherAltStartupList" -Name "$nameOfProgram"
		
	}
	if($regExist){
		
		if($debugout){
			write-host "About to Remove registry entry"
			write-host "startupList: $startupList"
			write-host "nameOfProgram: $nameOfProgram"
		}
		Remove-ItemProperty -Path "$startupList" -Name "$nameOfProgram"
			
	}
	if ($altRegExist){
		
		if($debugout){
			write-host "About to Remove registry entry"
			write-host "altStartupList: $altStartupList"
			write-host "nameOfProgram: $nameOfProgram"
		}
		Remove-ItemProperty -Path "$altStartupList" -Name "$nameOfProgram"

	}
	if ($anotherAltRegExist){
		if($debugout){
			write-host "About to Remove registry entry"
			write-host "anotherAltStartupList: $anotherAltStartupList"
			write-host "nameOfProgram: $nameOfProgram"
		}	
		Remove-ItemProperty -Path "$anotherAltStartupList" -Name "$nameOfProgram"

	}
}
#File and Folder removal.
try {
Remove-Item -Path "$exeInstallPath" -Recurse -Force -Confirm:$false 
}
catch {
	write-host "Application Install didnt exist in updated path"
}

try {
Remove-Item -Path "$exeInstallPath2" -Recurse -Force -Confirm:$false 
}
catch {
	write-host "Application was manually removed or failed to install properly - no uninstall required"
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
}
catch {
	write-host "already removed last trace off disk - only running in memory"
}
write-host "Successfully finished - Stopping Transcription of Process"
Stop-Transcript
write-host "0"
Return 0

