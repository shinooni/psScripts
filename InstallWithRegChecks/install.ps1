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
Start-Transcript -path "C:\Program Files (x86)\Win32Apps\dioutput.txt" -append
write-host "version dev3"

#Enable require requireRunOnEveryLogon if it needs to be a startup item
$requireRunOnEveryLogon = $true
$startupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$altStartupList = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
$anotherAltStartupList = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
$nameOfProgram = "DesktopInfo64"
$exeInstallPath = "C:\Program Files (x86)\Win32Apps\DesktopInfo"
$exeFile = "DesktopInfo64.exe"
$legacyPathClean = $true
[String[]]$oldInstallPaths = "C:\Win32Apps", "C:\Win32Apps"
[String[]]$extraFiles = "DesktopInfo64W.exe", "desktopinfo.ini", "libeay32.dll",`
						"ssleay32.dll", "GetCellularIP.ps1", "GetEthernetIP.ps1",`
						"GetWifiIP.ps1"



############################################################
#FUNCTIONS                                                 #
############################################################

function regExistCheck { 
	param ($regExpectedPath,$regExpectedValueName = "Not Entered",$regExpectedValueData = "Not Entered")
	#param filters
	$enteredValueName = $regExpectedValueName -ne "Not Entered"
	$enteredValueData = $regExpectedValueData -ne "Not Entered"
	#DEBUG switch
	$debugout = $true
	
	
	#check path
	$regKeyExists = Test-Path -Path $regExpectedPath
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
	$regEntryExists = Get-ItemProperty -Path $regExpectedPath -Name $regExpectedValueName
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
if($requireRunOnEveryLogon){
	$altValueData = "2 0 0 0 0 0 0 0 0 0 0 0"
	$preJoinedValueData = [string]::Join('\',$exeInstallPath,$exeFile)
	$checkIfRegExists = regExistCheck -regExpectedPath "$startupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$preJoinedValueData"
	$checkIfAltRegExists = regExistCheck -regExpectedPath "$altStartupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$altValueData"
	$checkIfAnotherAltRegExists = regExistCheck -regExpectedPath "$anotherAltStartupList" -regExpectedValueName "$nameOfProgram" -regExpectedValueData "$preJoinedValueData"
	
	$regDoesNotExist = "$checkIfRegExists" -ne "exists"
	$altRegDoesNotExist = "$checkIfAltRegExists" -ne "exists"
	$anotherAltRegDoesNotExist = "$checkIfAnotherAltRegExists" -ne "exists"
	$regExists = "$checkIfRegExists" -eq "exists"
	$anotherAltRegExists = "$checkIfAnotherAltRegExists" -eq "exists"
 

	if ($debugout){
		write-host "Variable Checkpoint"
		write-host "preJoinedValueData: $preJoinedValueData"
		write-host "checkIfRegExists: $checkIfRegExists"
		write-host "checkIfAltRegExists: $checkIfAltRegExists"
		write-host "checkIfAnotherAltRegExists = $checkIfAnotherAltRegExists"
		write-host "  "
		write-host "regDoesNotExist: $regDoesNotExist"
		write-host "altRegDoesNotExist: $altRegDoesNotExist"
		write-host "anotherAltRegDoesNotExist: $anotherAltRegDoesNotExist"
		write-host "  "
		write-host "=============="
	}
}




############################################################
#Install
############################################################
#Copy Files from package to a local location

New-Item -ItemType Directory -Force -Path $exeInstallPath | Out-Null
Copy-Item -Path "$PSScriptRoot\$exeFile" -Destination "$exeInstallPath\$exeFile"
foreach ($file in $extraFiles) {
	Copy-Item -Path "$PSScriptRoot\$file" -Destination "$exeInstallPath\$file"
}

#Add to Startup Items - Modifying registry entry
if($requireRunOnEveryLogon){
	if($debugout){
		write-host "Checking reg Does Not Exist - regDoesNotExist: $regDoesNotExist"
		write-host "startup list $startupList"
		write-host "name of program: $nameOfProgram"
		write-host "regDoesNotExist: $regDoesNotExist"
		write-host "altRegDoesNotExist: $altRegDoesNotExist"
		write-host "anotherAltRegDoesNotExist: $anotherAltRegDoesNotExist"
		Get-ItemProperty -Path "$startupList" -Name "$nameOfProgram"
		Get-ItemProperty -Path "$altStartupList" -Name "$nameOfProgram"
		Get-ItemProperty -Path "$anotherAltStartupList" -Name "$nameOfProgram"
	
	}
	if($regDoesNotExist -and ($altRegDoesNotExist -and $anotherAltRegDoesNotExist)){
		if($debugout){
			write-host "About to write registry entry"
			write-host "startup list $startupList"
			write-host "name of program: $nameOfProgram"
		}
		write-host "Writing new property"
		New-ItemProperty -Path "$startupList" -Name "$nameOfProgram" -PropertyType String -Value "$preJoinedValueData" -Force
		write-host "Setting new property"
		Set-ItemProperty -Path "$startupList" -Name "$nameOfProgram" -Value "$preJoinedValueData"
		write-host "Checking Input has happened"
		Get-ItemProperty -Path "$startupList"
	}
	if ($regExists -or $anotherAltRegExist) {
		Set-ItemProperty -Path "$startupList" -Name "$nameOfProgram" -Value "$preJoinedValueData"
	}
	
	#check alt locations - cause windows
	if ($debugout){
		write-host "Variable Checkpoint - Stage Two"
		write-host "preJoinedValueData: $preJoinedValueData"
		write-host "checkIfRegExists: $checkIfRegExists"
		write-host "checkIfAltRegExists: $checkIfAltRegExists"
		write-host "checkIfAnotherAltRegExists = $checkIfAnotherAltRegExists"
		write-host "  "
		write-host "regDoesNotExist: $regDoesNotExist"
		write-host "altRegDoesNotExist: $altRegDoesNotExist"
		write-host "anotherAltRegDoesNotExist: $anotherAltRegDoesNotExist"
		write-host "  "
		write-host "=============="
	}
	#dont need to write to any other places
	#You may need to alter which startupList path/var you use in the future.
	
}
if ($debugout){
		write-host "Variable Checkpoint - Stage Three"
		write-host "preJoinedValueData: $preJoinedValueData"
		write-host "checkIfRegExists: $checkIfRegExists"
		write-host "checkIfAltRegExists: $checkIfAltRegExists"
		write-host "checkIfAnotherAltRegExists = $checkIfAnotherAltRegExists"
		write-host "  "
		write-host "regDoesNotExist: $regDoesNotExist"
		write-host "altRegDoesNotExist: $altRegDoesNotExist"
		write-host "anotherAltRegDoesNotExist: $anotherAltRegDoesNotExist"
		write-host "  "
		write-host "========================================="
		write-host "Running Cleanup for old install locations"
		write-host "========================================="
		write-host "  "
	}
	if ($legacyPathClean) {
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

Stop-Transcript
write-host "0"
write-host "Ending Script as a Win"
Return 877378
