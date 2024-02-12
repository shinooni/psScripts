# DetectionScriptV2.ps1 
# 
# ====================================================
$script:debugout = $false
# Created Date: '22/01/2024'                        
# Author: 'Ted Hottes'
# Description: 'This script is used to detect' `
############# 'if an application is ' 
############# 'installed on the device.'  
#########################################

#########################################
# Variables - Modify these to suit your `
# application deployment
###
# Name of the application or setting
# ============>>  ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
$appOrSettingName   = 'Jabra Direct'

                    
# File test or Registry test - File/Registry
# ====>> ↓↓↓↓↓↓↓↓
$testType = 'File'

# '32-bit location for a file that is always' `
# 'named the same and exists at the same' `
# 'location on all devices and versions ' `
# 'of the application'
# =========>> ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
$32bitFileLocation  = 'C:\Program Files (x86)\JabraXpress\jabra-direct.exe'


# '64-bit location for a file that is always' `
# 'named the same and exists at the same' `
# 'location on all devices and versions ' `
# 'of the application'
# =========>> ↓↓↓↓↓↓↓↓↓↓↓↓
$64bitFileLocation  = 'C:\Program Files\JabraXpress\jabra-direct.exe'


# 'Registry path check instead of 
# 'file path check'
# ========>> ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
$registryPath   = 'HKLM:\SOFTWARE\' `
                + 'WOW6432Node\' `
                + 'Microsoft\Edge\' `
                + 'Extensions'

# 'Name of the registry value to check'
# ===>> ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
$Name = 'cpbdlogdokiacaifpokijfinplmdiapa'


# 'Value of the registry value to check'
# ==>> ↓↓↓
$Value = 'https://edge.microsoft.com/extensionwebstorebase/v1/crx'

# Extra registry entries to check for 
#
# keyName: is the name of the registry key to check for - if
# the variable is dynamicIter it will use and incrementing
# value based on previous values.
#
# regType: is the type of registry key to check for -
# REG_SZ, REG_DWORD, REG_BINARY, REG_MULTI_SZ,
# REG_EXPAND_SZ, REG_QWORD
#
# successState: can be 'Exists' or 'NotThere' to determine
# which state is a success(which should trigger an 
# install/exit 1).

[Array]$extraEntries = @( ###### Start of extraEntries Array ######

#+++++++++++++ Remove This Block To Use Array +++++++++++++++#
<# Comment out entries that are not needed - Remove these   ++
++ lines to remove one of the two comment tags - see bottom ++
++ of array                                                 ++
#+++++++++++++ Remove This Block To Use Array +++++++++++++++#

    @{  # First Entry - Extension Direct Path
        path                = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge\Extensions';
        keyName             = 'cpbdlogdokiacaifpokijfinplmdiapa'; 
        keyValue            = 'https://edge.microsoft.com/extensionwebstorebase/v1/crx';
        regType             = 'REG_SZ';
        successState        = 'Exists'
    }, 
    @{ # Second Entry - Extension Allow List
        path                = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallAllowlist';
        keyName             = 'dynamicIter'; 
        keyValue            = 'cpbdlogdokiacaifpokijfinplmdiapa'; 
        regType             = 'REG_SZ';
        successState        = 'Exists'
    },
    @{ # Third Entry - Extension Force List
        path                = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist';
        keyName             = 'dynamicIter'; 
        keyValue            = 'cpbdlogdokiacaifpokijfinplmdiapa'; 
        regType             = 'REG_SZ';
        successState        = 'Exists'
    }  #, # Remove the comment to add a third file - make sure the comma is 
    #    # uncommented.
    # @{ 
        # path                = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallAllowlist';
        # keyName             = 'dynamicInter'; 
        # keyValue            = 'cpbdlogdokiacaifpokijfinplmdiapa'; 
        # regType             = 'REG_SZ';
        # successState        = 'Exists'
    # }

#+++++++++++++ Remove This Block To Use Array +++++++++++++++#
#> #Remove this line to remove one of the two comment tags  ++
#+++++++++++++ Remove This Block To Use Array +++++++++++++++#

) ###### End of extraEntries Array ######

################################################
#Functions and Script Globals
################################################
function Write-Log {
    param (
        [string]$Message,
        [string]$Path = "C:\$appOrSettingName-detectionlog.log" # Specify the log file path
    )
    $messageToLog = "$(Get-Date) - $Message"
    Out-File -Append -FilePath $Path -InputObject $messageToLog
}
function getloggedindetails() {
    ##Find logged in username
    $user = Get-WmiObject Win32_Process -Filter "Name='explorer.exe'" |
        ForEach-Object { $_.GetOwner() } |
        Select-Object -Unique -Expand User

    ##Find logged in user's SID
    ##Loop through registry profilelist until ProfileImagePath matches and return the path
        $path= "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*"
        $sid = (Get-ItemProperty -Path $path | Where-Object { $_.ProfileImagePath -like "*$user" }).PSChildName

    $return = $sid, $user

    return $return
}
 
function regExistCheck { 
    param ($regExpectedPath,$regExpectedValueName = "Not Entered",$regExpectedValueData = "Not Entered")
    #param filters
    $enteredValueName = $regExpectedValueName -ne "Not Entered"
    $enteredValueData = $regExpectedValueData -ne "Not Entered"
    #DEBUG switch

    #check path
    $regKeyExists = Test-Path -Path $regExpectedPath
    if ($script:debugout) {
        Write-Log "Variable While checking for Reg Path"
        Write-Log "regExpectedPath: $regExpectedPath"
        Write-Log "regExpectedValueName: $regExpectedValueName"
        Write-Log "regExpectedValueData: $regExpectedValueData"
        Write-Log "enteredValueName: $enteredValueName"
        Write-Log "enteredValueData: $enteredValueData"
        Write-Log "regKeyExists: $regKeyExists"
    }
    
    if (-not $regKeyExists){
        Write-Log "Path doesn't exist"
        return "pathMissing"
    }
    
    Write-Log "Variable While checking for Reg Path"
    if(-not $enteredValueName){
        Write-Log "Only checked if path exists"
        return "exists"
    }
    if ($script:debugout) {
        Write-Log "path checked"
        Write-Log "regExpectedValueName: $regExpectedValueName"
    }
    
    #check value name
    $regEntryExists = Get-ItemProperty -Path $regExpectedPath -Name $regExpectedValueName
    if ($script:debugout){
        Write-Log "regEntryExists: $regEntryExists"
    }
    if (-not $regEntryExists){
        Write-Log "Value doesn't exist"
        return "keyMissing"
    }
    if(-not $enteredValueData){
        Write-Log "Didn't enter data value - So only checked Path and Value Name"
        return "exists"
    }
    
    if ($script:debugout) {
        Write-Log "value name checked"
    } 
    
    #check value data
    $currentRegValue = Get-ItemProperty -Path $regExpectedPath | Select-Object -ExpandProperty $regExpectedValueName 
    if ($script:debugout) {
        Write-Log "current reg value var: $currentRegValue"
        Write-Log "regExpectedValueData: $regExpectedValueData"
        Write-Log "current reg value loaded"
    }
    if ("$currentRegValue" -ne "$regExpectedValueData"){
        Write-Log "Expected reg value data didn't match"
        return "dataMissing"
    }
    if ($script:debugout){
        Write-Log "value data checked"
    }
    return "exists"	
}
# Use these variables if your in a user context

$script:loggedinuser = getloggedindetails
$script:sid = $loggedinuser[0]
$script:username = $loggedinuser[1]

################################################
#Logic or Code
################################################
# 'Which check are we doing?'
<#=========================#>

switch ($testType.ToLower()) {  
             
    'file' {  #__Detect a File__#
                                            
        ########################################
        # 'Check if the application' `
        # 'is installed in '  `
        # '32-bit location'             
        if (Test-Path $32bitFileLocation) {                
            Write-Log ("{0}" -f $appOrSettingName `
            + " detected, ignoring" )
            Write-Output ("{0}" -f $appOrSettingName `
            + " detected, ignoring" )    
            exit 0                              
                                                
        } else {                                
            ####################################                                   
            # 'Check if the application ' `
            # 'is installed' `
            # 'in 64-bit location'
            Write-Log Test-Path $64bitFileLocation              
            if (Test-Path $64bitFileLocation) {            
                Write-Log ("{0}" -f $appOrSettingName `
                + " detected, ignoring" )
                Write-Output ("{0}" -f $appOrSettingName `
                + " detected, ignoring" )       
                exit 0                          
                                                
            } else {                            
                                                
                # 'Application not detected,' `
                # 'trigger installation'
                Write-Log ("{0}" -f $appOrSettingName `
                + " not detected, installing" )   
                Write-Output ("{0}" -f $appOrSettingName `
                + " not detected, installing" )
                exit 1                          
                                                
            }                                   
        }                                       
    }  #_________________

    'registry' { #__ Detect a Registry Entry __#
        #############################################
        # Check if the registry path exists 
        #
        foreach ($entry in $extraEntries) {
            $regPath = $entry.path
            $keyName = $entry.keyName
            $keyValue = $entry.keyValue
            $regType = $entry.regType
            $successState = $entry.successState

            if ($script:debugout) {
                Write-Log "Variable While checking for Reg Path"
                Write-Log "regExpectedPath: $regPath"
                Write-Log "regExpectedValueName: $keyName"
                Write-Log "regExpectedValueData: $keyValue"
            }
            #Protective check
            $checkIfRegPathExists = regExistCheck -regExpectedPath "$regPath"
            if ($checkIfRegPathExists -eq "pathMissing") {
                Write-Log "Path doesn't exist"
                exit 1
            }

            #Check if the key is dynamicIter
            # if it is find keys check if the KeyValue
            # Matches and cycle through all keys
            if ($keyName -eq 'dynamicIter') {
                $registryObject = Get-ItemProperty -Path $regPath
                $arrayOfObjectProperties = $registryObject.PSObject.Properties | ForEach-Object { $_.Name }
                $arrayBound = [Array]::IndexOf($arrayOfObjectProperties, 'PSPath')
                [Array]$cleanArray = @()
                For($i = 0; $i -lt $arrayBound; $i++) {
                    $keyNameStore = $arrayOfKeys[$i]
                    $keyNameString = $keyNameStore.toString();
                    [Array]$cleanArray += $keyNameString
                }
                $arrayOfKeys = $cleanArray
                $arrayOfKeys = [Array]::Reverse($arrayOfKeys)
                for ($i = 0; $i -lt $arrayOfKeys.Length; $i++) {
                    $valueNameStore = $arrayOfKeys[$i]
                    $checkIfDynRegExists = regExistCheck -regExpectedPath "$regPath" -regExpectedValueName "$valueNameStore" -regExpectedValueData "$keyValue"
                    if($checkIfDynRegExists -eq "exists") {
                        Write-Log "Found a full match"
                        $script:regFound = $true
                    }
                    else {
                        Write-Log "No match or incomplete match found"
                        exit 1
                    }
                }
            } 
            else {
                $checkIfRegExists = regExistCheck -regExpectedPath "$regPath" -regExpectedValueName "$keyName" -regExpectedValueData "$keyValue"
                if ($checkIfRegExists -eq "exists") {
                    Write-Log "Found a full match"
                    $script:regFound = $true
                }
                else {
                    Write-Log "No match or incomplete match found"
                    exit 1
                }
            }
            
        }

        if (Test-Path $registryPath) {             
            $doesItExist = regExistCheck -regExpectedPath "$registryPath" -regExpectedValueName "$Name" -regExpectedValueData "$Value"
            #######################################
            # Check if the registry value exists   
            #
            if ($doesItExist -eq 'exists') {
                Write-Output ("RegistryPath:" `
                + "{0}" -f $registryPath `
                + " with key name {0}" -f $Name `
                + " and value {0}" -f $Value)           
                Write-Log ("RegistryPath:" `
                + "{0}" -f $registryPath `
                + " with key name {0}" -f $Name `
                + " and value {0}" -f $Value)
                Exit 0               
                                                    
            } else {
                if ($doesItExist -eq 'pathMissing') {
                    Write-Log ("RegistryPath: " `
                    + "{0} does not exist" -f $registryPath)
                    Write-Output ("RegistryPath: " `
                    + "{0} does not exist" -f $registryPath)
                    $script:regFound = $false    
                    Exit 1                                 
                }                               
                if ($doesItExist -eq 'keyMissing') {
                    Write-Log ("RegistryPath: " `
                    + "{0}  key: {1}" -f $registryPath, $Name `
                    + " does not exist")
                    Write-Output ("RegistryPath: " `
                    + "{0}  key: {1}" -f $registryPath, $Name `
                    + " does not exist")
                    $script:regFound = $false  	           
                    Exit 1                             
                }
                if ($doesItExist -eq 'dataMissing') {
                    Write-Log ("RegistryPath: " `
                    + "{0} Key: {1}" -f $registryPath, $Name `
                    + " {0} data does not match" -f $Value)
                    Write-Output ("RegistryPath: " `
                    + "{0} Key: {1}" -f $registryPath, $Name `
                    + " {0} data does not match" -f $Value)
                    $script:regFound = $false           
                    Exit 1                             
                }
                Exit 1 
            }
        } else {                                   
            # Write-Log "RegistryPath: " `
            # "$registryPath does not exist"
            $script:regFound = $false      
            Exit 1                                 
        } 
        if ($script:regFound) {
            Write-Log "All Registry Items and Values Found"	
            Exit 0
        } else {
            Write-Log "Something has not been found go ahead with install"	
            Exit 1
        }                                        
    }  #_________________

    default { #__# No Detection Method Selected #__#
                                                 
        ###########################################
        # 'No valid test type was selected so exit'
        #                                        
        Write-Log 'No valid test type ' `
        +'specified, exiting'                   
        Exit 1                                   
                                                 
    } #_________________

}

<#=========================#>