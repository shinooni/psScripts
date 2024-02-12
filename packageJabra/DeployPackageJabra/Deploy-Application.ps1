<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ##*===============================================
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
        Write-Log -Message "Unable to set execution policy for process to 'ByPass'." -Severity 3 -Source $deployAppScriptFriendlyName
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor <#==========#> = 'Jabra'
    [String]$appName <#============#> = 'Jabra Xpress'
    [String]$appInstallerFile <#===#> = 'JabraXpressx64.msi'

    # Parameters for the installer
    [String]$appInstallerParams <#=#> = '/quiet /qn /norestart XPRESSURL=https://backend-xpress.jabra.com PACKAGETOKEN=7XMei68fVgacXtY6ozN2MXKjmiUrvnUBYoLs55gdkTmPCUGSDhIBdBGdAUhhwQGNIf5ONN5ZQsZL0oVvFtDjFg=='

    # Parameters for the uninstaller
    [String]$appUninstallParams <#=#> = '/quiet /qn /norestart'
    [String]$operationType <#======#> = 'msiInstall'# msiInstall, exeInstall
    [String]$appDownloadUrl <#=====#> = '$false'    # Add a download URL if the file isn't included in the package
    [String]$appTypeOfInstall <#===#> = 'x64';      #x86, x64

    #keys for custom existance checks
    [String]$appCustomExistCheck <##> = '$false';   #true/false if you want to use a custom check for custom conditions. Outliers
    [String]$appKeyIdentifier <#===#> = 'JabraC';   #x86Access, x64Access - or anything you set as a keyword for 
                                                    # filter
                                                    # see
                                                    # function
                                                    # Test-ExistCustom
    [String]$appCustomInstallMethod   = '$false'; #true/false if you want to use a custom install method for custom conditions. Outliers
    [String]$appVersion <#=========#> = '5.4'
    [String]$appArch <#============#> = ''
    [String]$appLang <#============#> = 'EN'
    [String]$appRevision <#========#> = '01'
    [String]$appScriptVersion <#===#> = '1.0.0'
    [String]$appScriptDate <#======#> = '22/01/2024'
    [String]$appScriptAuthor <#====#> = 'Ted Hottes'

    # Apps to close before running the installer, comma separated, no spaces
    [String]$potentialClashApps <#=#> = 'jabra-direct.exe, jabradirect.exe'
    
    # Arrays for support files, args, operation types and download URLs if 
    # needed
    #  files -----------# Includes the name of the file(s) to be downloaded  
    #                   # if the file isn't included in the package
    #  args ------------# Includes the arguments to be used when running 
    #                   # the file(s)
    #  operationType ---# Includes the operation type of the file(s) 
    #                   # exeInstall, msiInstall ; Expand as needed
    #  downloadURL -----# Includes the URL to download the file from if the  
    #                   # file isn't included in the package - $false if
    #                   # not needed
    #  typeOfInstall ---# x86 or X64 what type of application is it / installer
    #                   # Expand as needed
    #  customExistCheck-# true/false if you want to use a custom check for  
    #                   # custom conditions. Outliers
    #
    #  keyIdentifier ---# x86Access, x64Access - or anything you set as 
    #                   # a keyword for filter see function Test-ExistCustom
    #                   # only needed if customExistCheck is set to true 
    #                   # otherwise set to false


    [Array]$supportFiles = @( ###### Start of supportFiles Array ######

        @{  # First file - Not a File but an insurance policy making sure the previous version is uninstalled
            name                = 'Jabra Direct';
            file                = 'jabradirectUninstall.exe'; 
            args                = '/quiet /qn /norestart'; 
            operationType       = 'exeInstall';
            typeOfInstall       = 'x86';
            customExistCheck    = '$true';
            keyIdentifier       = 'jabraDirectUninstall';
            downloadURL         = '$false';
            keepOnUninstall     = '$false';
            uninstallArgs       = '/uninstall /passive /quiet /norestart'
        }
<# Delete this line to uncomment the supportFiles array, 
        @{ # Second file - MS 2016 Access Database Engine Redistributable X64
            name                = 'Access database engine 2016';
            file                = 'accessdatabaseengine_X64.exe'; 
            args                = '/passive /quiet /norestart'; 
            operationType       = 'exeInstall';
            typeOfInstall       = 'x64';
            customExistCheck    = '$true';
            keyIdentifier       = 'x64Access';
            downloadURL         = '$false'; 
            keepOnUninstall     = '$true';
            uninstallArgs       = '/passive /quiet /norestart'
        } #, # Remove the comment to add a third file - make sure the comma is 
        #    # uncommented.
        # @{ 
        #     name              = 'Access database engine 2016';
        #     file              = accessdatabaseengine_X64.exe; 
        #     args              = '/passive /quiet /norestart'; 
        #     operationType     = 'exeInstall'; 
        #     downloadURL       = '$false';
        #     keepOnUninstall   = '$true';
        #     uninstallArgs     = '/passive /quiet /norestart'
        # } 
#> #Delete this line to uncomment the supportFiles array
    ) ###### End of supportFiles Array ######



    ##########################################
    # add custom logic to check if the file, program or
    # other exists it will auto fallback to standard query
    # methods. If this function doesn't catch. Only for
    # outliers.
    # Expected return values are 'exists', 'notFound'
    # please return one or the other.
    
    function Test-ExistCustom($keyidentifier) {
        # when writing this custom function, please return
        # 'exists' or 'notFound'
        # if the file, program or other exists it will
        # ignore the install and move on to the next
        # support file. If it doesn't exist it will install.
        $driverName = "Microsoft Access Driver (*.mdb, *.accdb)"
        $x86RegistryPath = 'HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBCINST.INI\ODBC Drivers'
        $x64RegistryPath = 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers'

        $x86Installed = Test-Path -Path $x86RegistryPath\$driverName
        $x64Installed = Test-Path -Path $x64RegistryPath\$driverName
        $installReturn = ''
        Write-Log -Message "Checking if $keyidentifier is installed" -Severity 1 -Source $deployAppScriptFriendlyName
        # Extra logic to catch if jabra direct hasn't been
        # uninstalled first - edge case so no dedicated
        # function.
        if($keyidentifier -eq 'jabraDirectUninstall'){
            Write-Log -Message "Checking if Jabra Direct is installed" -Severity 1 -Source $deployAppScriptFriendlyName
            $keyToFind = 'jabraDirectUninstall'
            $hashOfKey = $supportFiles | Where-Object { $_.KeyIdentifier -eq $keyToFind }
            ForEach ($hash in $hashOfKey){
                
                $cleanOldJabra = Get-InstalledApplication -Name $hash.name
                
                ForEach ($jabraInfo in $cleanOldJabra){
                    #Handle if it return multiple objects.
                    try {
                        $popFirstJabra = $cleanOldJabra | Select-Object -First 1
                        if ($null -eq $popFirstJabra) {
                            $popFirstJabra = 'Nothing left to uninstall'
                        }
                    } 
                    catch {
                        $popFirstJabra = 'Nothing left to uninstall'
                    }
                    Write-Log -Message "JabraUninstall set Found $($popFirstJabra.DisplayName) $($popFirstJabra.DisplayVersion) and a valid uninstall string, now attempting to uninstall." -Severity 1 -Source $deployAppScriptFriendlyName
                    #If uninstall string property exists
                    Write-Log -Message "Checking if $($hash.name) is installed" -Severity 1 -Source $deployAppScriptFriendlyName
                    Write-Log -Message "Checking if $($popFirstJabra.DisplayName) is available and uninstallable as per: $($popFirstJabra.UninstallString)" -Severity 1 -Source $deployAppScriptFriendlyName
                    Write-Log -Message "Jabra pop $($popFirstJabra) is installed" -Severity 1 -Source $deployAppScriptFriendlyName
                    If($hash.name -like "*$($popFirstJabra.DisplayName)*"){
                        If($popFirstJabra.UninstallString){
                            $extractJustPath = $popFirstJabra.UninstallString -replace ' /.*$'
                            $UninstPath = $($extractJustPath).Replace('"','')
                            $UninstPath = $UninstPath.ToString()
                            Write-Log -Message "Uninstall Jabra Path is $($UninstPath)" -Severity 1 -Source $deployAppScriptFriendlyName
                            
                            switch -Regex ($UninstPath) {

                                # Matches a file path ending in '.exe' but not containing 'MsiExec.exe' or 'MsiExec'
                                '^(?!.*MsiExec).*\.exe.*$' {

                                    # Confirms path exists
                                    # and is a file
                                    If(Test-Path -Path $UninstPath){

                                        Write-Log -Message "Going to uninstall now - Found $($popFirstJabra.DisplayName) $($popFirstJabra.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                                        Execute-Process -Path $UninstPath -Parameters $hash.uninstallArgs -WaitForMsiExec -MsiExecWaitTime 240 -WindowStyle Hidden
                                        Start-Sleep -Seconds 20

                                    }
                                }

                                # Matches a file path ending in '.msi' or a string containing 'MsiExec' (with optional '.exe') followed by the uninstall command
                                '(\.msi$)|((?:.*\s)?MsiExec(?:\.exe)?\s+/X\{[A-F0-9-]+\})' { 
                                    if((Test-Path -Path $UninstPath) -or ($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')){
                                        if(($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')){

                                            # Find the index of the first opening brace and the closing brace
                                            $start = $inputString.IndexOf('{')
                                            $end = $inputString.IndexOf('}', $start)

                                            # If both braces are found, extract the substring between them
                                            if ($start -ne -1 -and $end -ne -1) {
                                                $UninstPath = $inputString.Substring($start, $end - $start + 1)
                                            }
                                        }

                                        Write-Log -Message "Going to Uninstall MSI - Found $($popFirstJabra.DisplayName) $($popFirstJabra.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                                        Execute-MSI -Action 'Uninstall' -Path $UninstPath -Parameters $hash.uninstallArgs
                                        Start-Sleep -Seconds 20

                                    }
                                }
                                
                                default {
                                    $installReturn = 'exists'
                                }
                            }
                        }
                    } 
                }
            }
            $installReturn = 'exists'
        }
        #x86 and x64 access driver check
        if($keyidentifier -eq 'x86Access'){
            if ($x86Installed) {
                Write-Log "x86 (32-bit) version of the ODBC driver is installed."
                $installReturn = 'exists'
            } 
            else {
                Write-Log "x86 (32-bit) version of the ODBC driver is not installed."
                $installReturn = 'notFound'
            }
        }
        if($keyidentifier -eq 'x64Access'){
            if ($x64Installed) {
                Write-Log "x64 (64-bit) version of the ODBC driver is installed."
                $installReturn = 'exists'

            } 
            else {
                Write-Log "x64 (64-bit) version of the ODBC driver is not installed."
                $installReturn = 'notFound'
            }
        }
        
        #return the result of the custom check
        return $installReturn
    }

    function Install-CustomMethod($keyIdentifier) {
        # # Add custom install logic here - return true if installed or false if not
        # if ($keyIdentifier -eq 'x86Access'){
        #     #Custom Install Logic for the InstallPhase
        #     return '$true'
        # }
        return '$false'
    }
    function Post-InstallCustomMethod($keyIdentifier) {
        # # Add custom post- install logic here - return true if installed or false if not
        # if ($keyIdentifier -eq 'x86Access'){
        #     #Custom Install Logic for the PostInstallPhase
        #     return '$true'
        # }
        return '$false'
    }
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set 
    ## by the toolkit)
    [String]$installName = ''
    [String]$installTitle = 'JabraXpress'
    [String]$keyForFindingUninstallInformation = 'Jabra Xpress'
    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/01/2024'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Ge Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Microsoft Intune Win32 App Workaround for 32-bit PowerShell Hosts - Defensive Code
        If (!([Environment]::Is64BitProcess)) {
            If ([Environment]::Is64BitOperatingSystem) {
                Write-Log -Message "Running 32-bit Powershell on 64-bit OS, Restarting as 64-bit Process..." -Severity 2
                $Arguments = "-NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -File `"" + $myinvocation.mycommand.definition + "`""
                $Path = (Join-Path $Env:SystemRoot -ChildPath "\sysnative\WindowsPowerShell\v1.0\powershell.exe")
                Start-Process -FilePath $Path -ArgumentList $Arguments -Verb RunAs
                Write-Log -Message "Win32 workaround completed successfully, Running x64 powershell version" -Severity 2
                Exit
            }
            Else {
                Write-Log -Message "Running 32-bit Powershell on 32-bit OS, No Win32 workaround required" -Severity 2
            }
        }


        ## Show Welcome Message, Close potential interacting processes, 
        ## allow up to 60 seconds for the process to exit
        Show-InstallationWelcome -CloseApps $potentialClashApps -BlockExecution -CloseAppsCountdown 60
        
        #### Using a code ide you can select the code below and press 
        #### ctrl+k+c to comment out the code or ctrl+k+u to uncomment the code
        #### Doing so will reimplement logic for uninstalling previous versions
        #### of software.
        # ## Show Progress Message (With a Message to Indicate the Application 
        # ## is Being Uninstalled)
        # Show-InstallationProgress -StatusMessage "Removing Any Existing" `
        # + "Version of $appName. Please Wait..."
        # ## Remove Any Existing Versions of the Application (MSI)
        # Remove-MSIApplications "$keyForFindingUninstallInformation"
        # ## Remove Any Existing Version of TeamViewer or TeamViewer Host (EXE)
        # $AppList = Get-InstalledApplication `
        #               -Name "$keyForFindingUninstallInformation"
        # ForEach ($App in $AppList){
        #     If($App.UninstallString){
            
                # $extractJustPath = $App.UninstallString -replace ' /.*$'
                # $UninstPath = $($extractJustPath).Replace('"','')
                # $UninstPath = $UninstPath.ToString()   
        #         If(Test-Path -Path $UninstPath){
                      
        #             Write-Log -Message "Found $($App.DisplayName) " `
        #             + "$($App.DisplayVersion) and a valid uninstall" `
        #             + " string, now attempting to uninstall."
        #             Execute-Process -Path $UninstPath -Parameters '/S'
        #             Start-Sleep -Seconds 5

        #         }
        #     }
        # }
        ######################################################################
        # ## End of Previous Version Uninstall Logic / Clean Up
        ######################################################################

        ## Show Progress Message (with the default message)
        Show-InstallationProgress `
            -StatusMessage 'Installing All Support Files'

        ## Check if there is anything in the support files folder or if there
        ## is a noted download location
        $supportDirCheck = Test-Path -Path "$dirSupportFiles\*"

        ## Check if the support files array has any download URLs
        $checkSupportDownloadRequired = $supportFiles | `
                Where-Object { $_.downloadURL -like "*http*" }
        
        # # Set the support install path to the default support files folder,
        # # Provide logic for if there is a download URL, set the path to the 
        # # download folder
        $supportInstallPath = $dirSupportFiles
        Write-Log -Message "Checking Support Files Exist to Install" `
            -Severity 1 -Source $deployAppScriptFriendlyName

        If ($supportDirCheck -or $checkSupportDownloadRequired) {

            # Support files download location - do not modify unless you want to 
            # change where the files are downloaded to ensure the path always exists
            [String]$supportDownloadTempFolder = "$dirSupportFiles\Downloads"
            New-Item -ItemType Directory -Force -Path $supportDownloadTempFolder | Out-Null

            # # Iterate through the supportFiles array and install each file 
            # #  keep track of index for referencing purposes
            Write-Log -Message ("Found $($supportFiles.Count) Support Files " `
                + "to Install") -Severity 1 -Source $deployAppScriptFriendlyName
            foreach ($supportFile in $supportFiles) {
                Write-Log -Message "Installing $($supportFile.name) $($supportFile.file) $($supportFile.args)" -Severity 1 -Source $deployAppScriptFriendlyName
                
                ## Check if the file should be downloaded 
                Write-Log -Message "Checking if $($supportFile.file) should be downloaded" -Severity 1 -Source $deployAppScriptFriendlyName
                if ($supportFile.downloadURL -like '*http*') {
                    Write-Log -Message "Downloading $($supportFile.name) $($supportFile.file) from $($supportFile.downloadURL)" -Severity 1 -Source $deployAppScriptFriendlyName
                    # Make hash property a flat variable - just in case
                    $downloadSupportFileName = $supportFile.file
                    (New-Object System.Net.WebClient).DownloadFile($supportFile.downloadURL, "$supportDownloadTempFolder\$downloadFileName")

                    $supportInstallPath = $supportDownloadTempFolder
                    Write-Log -Message "Downloaded $($supportFile.name) $($supportFile.file) to $($supportDownloadTempFolder)" -Severity 1 -Source $deployAppScriptFriendlyName
                }

                # Ensure the file exists/downloaded properly in the support
                # files folder
                Write-Log -Message "Checking if $($supportFile.file) exists in $($supportInstallPath)" -Severity 1 -Source $deployAppScriptFriendlyName
                $supportFilePath = Get-ChildItem -Path "$supportInstallPath" -Include $supportFile.file -File -Recurse -ErrorAction SilentlyContinue
                $script:requireInstall = $true
                If ($supportFilePath.Exists) {
                    
                    Write-Log -Message "Found $($supportFilePath.FullName) in $($supportInstallPath)" -Severity 1 -Source $deployAppScriptFriendlyName
                    ## Check if the file is an executable or an MSI and install accordingly
                    $fileExtension = [System.IO.Path]::GetExtension($supportFilePath)
                    switch ($fileExtension) {
                        # Add to this list as needed

                        # If the file is an executable, install it
                        ".exe" {
                            $script:requireInstall = $true
                            Write-Log -Message "Found $($supportFilePath.FullName) as an Executable, now attempting to install. For $appName pre-requisites."
                            Show-InstallationProgress "Installing $($supportFilePath.FullName) for $appName pre-requisites."
                            # check for if the program
                            # already exists or not.
                            if($supportFile.customExistCheck.ToLower() -eq '$true'){
                                $installCheck = Test-ExistCustom $supportFile.keyIdentifier
                                if($installCheck -eq 'notFound'){
                                    $script:requireInstall = $true
                                }
                                else{
                                    Write-Log -Message "Found $($supportFilePath.FullName) as an Executable, but it is already installed. Skipping install. For $appName pre-requisites."
                                    $script:requireInstall = $false
                                }
                            } 
                            else {
                                # Check if the file exists
                                # through normal means
                                
                                try{
                                    $psadtInstallCheck = Get-InstalledApplication -Name $supportFile.name
                                    foreach($app in $psadtInstallCheck){
                                        if($app.DisplayName -like $supportFile.name){
                                            if($supportFile.typeOfInstall.ToLower() -eq 'x86'){
                                                if($app.Is64BitApplication -eq $false){
                                                    Write-Log -Message "Found $($supportFilePath.FullName) as an Executable, but it is already installed. Skipping install. For $appName pre-requisites."
                                                    $script:requireInstall = $false
                                                }
                                            }
                                            elseif($supportFile.typeOfInstall.ToLower() -eq 'x64'){
                                                if($app.Is64BitApplication -eq $true){
                                                    Write-Log -Message "Found $($supportFilePath.FullName) as an Executable, but it is already installed. Skipping install. For $appName pre-requisites."
                                                    $script:requireInstall = $false
                                                }  
                                            }
                                        }
                                    }
                                }
                                catch {
                                    Write-Log -Message "Something Went wrong with the install check for $($supportFile.name). Continuing with install."
                                }
                            }
                            if($script:requireInstall -eq $true){
                                # handle many return types
                                # for true or false
                                $customInstallRequired = Install-CustomMethod $supportFile.keyIdentifier
                                [String]$customInstallRequired = $customInstallRequired.ToString()
                                
                                if (($customInstallRequired -eq 1) -or ($customInstallRequired -eq '1')){
                                    $customInstallRequired = 'true'
                                }
                                elseif (($customInstallRequired -eq 0) -or ($customInstallRequired -eq '0')){
                                    $customInstallRequired = 'false'
                                }
                                
                                if (($customInstallRequired.ToLower() -eq '$false') -or ($customInstallRequired.ToLower() -eq 'false')){
                                    #Last check that file
                                    # exists
                                    if($supportFilePath.Exists){
                                        Execute-Process -Path $supportFilePath -Parameters $supportFile.args -WaitForMsiExec -MsiExecWaitTime 240 -WindowStyle Hidden
                                    }
                                }

                            }
                        }

                        # If the file is an MSI, install it
                        ".msi" {
                            $script:requireInstall = $true
                            Write-Log -Message "Found $($supportFilePath.FullName) as an MSI, now attempting to install. For $appName pre-requisites."
                            Show-InstallationProgress "Installing $($supportFilePath.FullName) for $appName pre-requisites."
                            if(($supportFile.customExistCheck.ToLower() -eq '$true') -or ($supportFile.customExistCheck.ToLower() -eq 'true')){
                                $installCheck = Test-ExistCustom $supportFile.keyIdentifier
                                if($installCheck -eq 'notFound'){
                                    $script:requireInstall = $true
                                }
                                elseif($installCheck -eq 'exists'){
                                    Write-Log -Message "Found $($supportFilePath.FullName) as an msi, but it is already installed. Skipping install. For $appName pre-requisites."
                                    $script:requireInstall = $false
                                }
                            } else {
                                # Check if the file exists
                                # through normal means
                                
                                try{
                                    $psadtInstallCheck = Get-InstalledApplication -Name $supportFile.name
                                    foreach($app in $psadtInstallCheck){
                                        if($app.DisplayName -like $supportFile.name){
                                            if($supportFile.typeOfInstall.ToLower() -eq 'x86'){
                                                if($app.Is64BitApplication -eq $false){
                                                    Write-Log -Message "Found $($supportFilePath.FullName) as an msi, but it is already installed. Skipping install. For $appName pre-requisites."
                                                    $script:requireInstall = $false
                                                }
                                            }
                                            elseif($supportFile.typeOfInstall.ToLower() -eq 'x64'){
                                                if($app.Is64BitApplication -eq $true){
                                                    Write-Log -Message "Found $($supportFilePath.FullName) as an msi, but it is already installed. Skipping install. For $appName pre-requisites."
                                                    $script:requireInstall = $false
                                                }  
                                            }
                                        }
                                    }
                                }
                                catch {
                                    Write-Log -Message "Something Went wrong with the install check for $($supportFile.name). Continuing with install."
                                }
                            }
                            if($script:requireInstall -eq $true){

                                $customInstallRequired = Install-CustomMethod $supportFile.keyIdentifier
                                [String]$customInstallRequired = $customInstallRequired.ToString()
                                
                                if (($customInstallRequired -eq 1) -or ($customInstallRequired -eq '1')){
                                    $customInstallRequired = 'true'
                                }
                                elseif (($customInstallRequired -eq 0) -or ($customInstallRequired -eq '0')){
                                    $customInstallRequired = 'false'
                                }
                                
                                if (($customInstallRequired.ToLower() -eq '$false') -or ($customInstallRequired.ToLower() -eq 'false')){
                                    # Last check that file
                                    # exists
                                    if($supportFilePath.Exists){
                                        Execute-MSI -Action 'Install' -Path $supportFilePath -Parameters $supportFile.args
                                    }
                                }
                                
                            }
                        }

                        # If the file is neither an executable or an MSI, log it and move on
                        default {
                            Write-Log -Message "Unsupported file type: $fileExtension" -Severity 3 -Source $deployAppScriptFriendlyName
                        }
                    }
                }
                Else {
                    Write-Log -Message "$($supportFile.file) not found in SupportFiles folder" -Severity 3 -Source $deployAppScriptFriendlyName
                }
            }
        }
        Else {
            Write-Log -Message 'No Support Files Found - If support files are meant to exist, make sure they are in the support files folder before repackaging' -Severity 1 -Source $deployAppScriptFriendlyName
        }
    

        ## <Perform Pre-Installation tasks here>
        ### Boilerplate code for downloading files from the internet and installing them.
        # 
        # New-Item -ItemType Directory -Force -Path $supportDownloadTempFolder | Out-Null
        # (New-Object System.Net.WebClient).DownloadFile('https://www.dropbox.com/download?full=1&os=win&arch=x64', "$supportDownloadTempFolder\$supportFile.file") | Start-Process -Wait -FilePath "$supportDownloadTempFolder\$supportFile.file" -ArgumentList '/NOLAUNCH' -PassThru


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## <Perform Installation tasks here>

        If ($ENV:PROCESSOR_ARCHITECTURE -eq 'x86') {
            Write-Log -Message 'Detected x86 OS' -Severity 1 -Source $deployAppScriptFriendlyName
        }

        ## Check if the installer has download location. If it does, download
        $checkInstallDownloadRequired = $appDownloadUrl -like "*http*"

        $appDirCheck = Test-Path -Path "$dirFiles\*"
        $appDir = "$dirFiles\*"
        If ($appDirCheck -or $checkInstallDownloadRequired) {

            # Download location - do not modify unless you want to 
            # change where the files are downloaded to ensure the path always exists
            [String]$appDownloadTempFolder = "$dirFiles\Downloads"
            New-Item -ItemType Directory -Force -Path $appDownloadTempFolder | Out-Null

            Write-Log -Message "Checking if $appInstallerFile should be downloaded" -Severity 1 -Source $deployAppScriptFriendlyName
            if ($checkInstallDownloadRequired) {
                Write-Log -Message "Downloading $appInstallerFile from $appDownloadUrl" -Severity 1 -Source $deployAppScriptFriendlyName
                # Make hash property a flat variable - just in
                # case
                
                $downloadAppFileName = $appInstallerFile
                (New-Object System.Net.WebClient).DownloadFile($appDownloadUrl, "$appDownloadTempFolder\$downloadAppFileName")

                $appDirCheck = Test-Path -Path "$appDownloadTempFolder\*"
                $appDir = "$dirFiles\*"
                Write-Log -Message "Downloaded $appInstallerFile to $appDownloadTempFolder" -Severity 1 -Source $deployAppScriptFriendlyName
            }

            # Ensure the file exists/downloaded properly in the
            # standard Files sub-folder
            Write-Log -Message "Checking if $appInstallerFile exists in $appDir" -Severity 1 -Source $deployAppScriptFriendlyName
            $appInstallerPath = Get-ChildItem -Path "$appDir" -Include $appInstallerFile -File -Recurse -ErrorAction SilentlyContinue
            If ($appInstallerPath.Exists) {
                Write-Log -Message "Found $($appInstallerPath.FullName) in $($appDir)" -Severity 1 -Source $deployAppScriptFriendlyName
                ## Check if the file is an executable or an MSI and install accordingly
                $fileExtension = [System.IO.Path]::GetExtension($appInstallerPath)
                switch ($fileExtension) {
                    # Add to this list as needed

                    # If the file is an executable, install it
                    ".exe" {
                        $script:requireInstall = $true
                        Write-Log -Message "Found $($appInstallerPath.FullName) as an Executable, now attempting to install. For $appName."
                        Show-InstallationProgress "Installing $($appInstallerPath.FullName) for $appName."
                        if(($appCustomExistCheck.ToLower() -eq '$true') -or ($appCustomExistCheck.ToLower() -eq 'true')){
                            $installCheck = Test-ExistCustom $appKeyIdentifier
                            if($installCheck -eq 'notFound'){
                                $script:requireInstall = $true
                            }
                            elseif($installCheck -eq 'exists'){
                                Write-Log -Message "Found $($appInstallerPath.FullName) as an Executable, but it is already installed. Skipping install."
                                $script:requireInstall = $false
                            }
                        }
                        else {
                            # Check if the file exists
                            # through normal means
                            
                            try{
                                $psadtInstallCheck = Get-InstalledApplication -Name $appName
                                foreach($app in $psadtInstallCheck){
                                    if($app.DisplayName -like $appName){
                                        if($appTypeOfInstall.ToLower() -eq 'x86'){
                                            if($app.Is64BitApplication -eq $false){
                                                Write-Log -Message "Found $($appInstallerPath.FullName) as an Executable, but it is already installed. Skipping install."
                                                $script:requireInstall = $false
                                            }
                                        }
                                        elseif($appTypeOfInstall.ToLower() -eq 'x64'){
                                            if($app.Is64BitApplication -eq $true){
                                                Write-Log -Message "Found $($appInstallerPath.FullName) as an Executable, but it is already installed. Skipping install."
                                                $script:requireInstall = $false
                                            }  
                                        }
                                    }
                                }
                            }
                            catch {
                                Write-Log -Message "Something Went wrong with the install check for  $($appInstallerPath.FullName). Continuing with install."
                            }
                        }
                        if($script:requireInstall -eq $true){
                            $customInstallRequired = Install-CustomMethod $appKeyIdentifier
                            [String]$customInstallRequired = $customInstallRequired.ToString()
                            
                            if (($customInstallRequired -eq 1) -or ($customInstallRequired -eq '1')){
                                $customInstallRequired = 'true'
                            }
                            elseif (($customInstallRequired -eq 0) -or ($customInstallRequired -eq '0')){
                                $customInstallRequired = 'false'
                            }
                            
                            if (($customInstallRequired.ToLower() -eq '$false') -or ($customInstallRequired.ToLower() -eq 'false')){
                                # Last Check if install
                                # file exists
                                if($appInstallerPath.Exists){
                                    Execute-Process -Path $appInstallerPath -Parameters $appInstallerParams -WaitForMsiExec -MsiExecWaitTime 240 -WindowStyle Hidden
                                }
                            }
                        }
                    }

                    # If the file is an MSI, install it
                    ".msi" {
                        $script:requireInstall = $true
                        Write-Log -Message "Found $($appInstallerPath.FullName) as an MSI, now attempting to install. For $appName."
                        Show-InstallationProgress "Installing $($appInstallerPath.FullName) for $appName."
                        if(($appCustomExistCheck.ToLower() -eq '$true') -or ($appCustomExistCheck.ToLower() -eq 'true')){
                            
                            $installCheck = Test-ExistCustom $appKeyIdentifier
                            if($installCheck -eq 'notFound'){
                                $script:requireInstall = $true
                            }
                            elseif($installCheck -eq 'exists'){
                                Write-Log -Message "Found $($appInstallerPath.FullName) as an msi, but it is already installed. Skipping install."
                                $script:requireInstall = $false
                            }
                        }
                        else {
                            # Check if the file exists
                            # through normal means
                            
                            try{
                                $psadtInstallCheck = Get-InstalledApplication -Name $appName
                                foreach($app in $psadtInstallCheck){

                                    if($app.DisplayName -like $appName){

                                        if($appTypeOfInstall.ToLower() -eq 'x86'){

                                            if($app.Is64BitApplication -eq $false){
                                                Write-Log -Message "Found $($appInstallerPath.FullName) as an msi, but it is already installed. Skipping install."
                                                $script:requireInstall = $false
                                            }
                                        }
                                        elseif($appTypeOfInstall.ToLower() -eq 'x64'){
                                            
                                            if($app.Is64BitApplication -eq $true){
                                                Write-Log -Message "Found $($appInstallerPath.FullName) as an msi, but it is already installed. Skipping install."
                                                $script:requireInstall = $false
                                            }  
                                        }
                                    }
                                }
                            }
                            catch {
                                Write-Log -Message "Something Went wrong with the install check for  $($appInstallerPath.FullName). Continuing with install."
                            }
                        }
                        if($script:requireInstall -eq $true){
                            $customInstallRequired = Install-CustomMethod $appKeyIdentifier
                            [String]$customInstallRequired = $customInstallRequired.ToString()
                            
                            if (($customInstallRequired -eq 1) -or ($customInstallRequired -eq '1')){
                                $customInstallRequired = 'true'
                            }
                            elseif (($customInstallRequired -eq 0) -or ($customInstallRequired -eq '0')){
                                $customInstallRequired = 'false'
                            }
                            
                            if (($customInstallRequired.ToLower() -eq '$false') -or ($customInstallRequired.ToLower() -eq 'false')){
                                # Last Check if install
                                # file exists
                                if($appInstallerPath.Exists){
                                    Execute-MSI -Action 'Install' -Path $appInstallerPath -Parameters $appInstallerParams
                                }
                            }
                        }
                    }

                    # If the file is neither an executable or an MSI, log it and move on
                    default {
                        Write-Log -Message "Unsupported file type: $fileExtension" -Severity 3 -Source $deployAppScriptFriendlyName
                    }
                }
            }
            Else {
                Write-Log -Message "$appInstallerFile not found in Files folder" -Severity 3 -Source $deployAppScriptFriendlyName
            }
        }
        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
        foreach ($supportFile in $supportFiles){
            Post-InstallCustomMethod $supportFile.keyIdentifier
        }
        Post-InstallCustomMethod $appKeyIdentifier
        ## Display a message at the end of the install
        # If (-not $useDefaultMsi) {
        #     Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
        # }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'
        ## Microsoft Intune Win32 App Workaround for 32-bit PowerShell Hosts - Defensive Code
        If (!([Environment]::Is64BitProcess)) {
            If ([Environment]::Is64BitOperatingSystem) {
                Write-Log -Message "Running 32-bit Powershell on 64-bit OS, Restarting as 64-bit Process..." -Severity 2
                $Arguments = "-NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -File `"" + $myinvocation.mycommand.definition + "`""
                $Path = (Join-Path $Env:SystemRoot -ChildPath "\sysnative\WindowsPowerShell\v1.0\powershell.exe")
                Start-Process -FilePath $Path -ArgumentList $Arguments -Verb RunAs
                Write-Log -Message "Win32 workaround completed successfully, Running x64 powershell version" -Severity 2
                Exit
            }
            Else {
                Write-Log -Message "Running 32-bit Powershell on 32-bit OS, No Win32 workaround required" -Severity 2
            }
        }


        ## Show Welcome Message, Close potential interacting processes, 
        ## allow up to 60 seconds for the process to exit
        Show-InstallationWelcome -CloseApps $potentialClashApps -BlockExecution -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'
        ## <Perform Uninstallation tasks here>
        $AppList = Get-InstalledApplication -Name $appName
        
        ForEach ($App in $AppList){
            #If uninstall string property exists
            If($App.UninstallString){

                $extractJustPath = $App.UninstallString -replace ' /.*$'
                $UninstPath = $($extractJustPath).Replace('"','')
                $UninstPath = $UninstPath.ToString()
                switch -Regex ($UninstPath) {

                    # Matches a file path ending in '.exe' but not containing 'MsiExec.exe' or 'MsiExec'
                    '^(?!.*MsiExec).*\.exe$' { 
                        # Confirms path exists and is a file
                        If(Test-Path -Path $UninstPath){
                            Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                            Execute-Process -Path $UninstPath -Parameters $appUninstallParams -WaitForMsiExec -MsiExecWaitTime 240 -WindowStyle Hidden
                            Start-Sleep -Seconds 20
                        }
                    }
            
                    # Matches a file path ending in '.msi' or a string containing 'MsiExec' (with optional '.exe') followed by the uninstall command
                    '(\.msi$)|((?:.*\s)?MsiExec(?:\.exe)?\s+/X\{[A-F0-9-]+\})' { 
                        if((Test-Path -Path $UninstPath) -or ($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')){
                            if(($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')){

                                # Find the index of the first opening brace and the closing brace
                                $start = $inputString.IndexOf('{')
                                $end = $inputString.IndexOf('}', $start)

                                # If both braces are found, extract the substring between them
                                if ($start -ne -1 -and $end -ne -1) {
                                    $UninstPath = $inputString.Substring($start, $end - $start + 1)
                                }
                            }
                            Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                            Execute-MSI -Action 'Uninstall' -Path $UninstPath -Parameters $appUninstallParams
                            Start-Sleep -Seconds 20
                        }
                    }
            
                    default { 
                        Write-Log -Message "$($App.DisplayName) $($App.DisplayVersion) Couldn't Find a Valid Way to Uninstall. Please Uninstall Manually." -Severity 3 -Source $deployAppScriptFriendlyName
                    }
                }        
            }
        }

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }



        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'
        
        If (!([Environment]::Is64BitProcess)) {
            If ([Environment]::Is64BitOperatingSystem) {
                Write-Log -Message "Running 32-bit Powershell on 64-bit OS, Restarting as 64-bit Process..." -Severity 2
                $Arguments = "-NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -File `"" + $myinvocation.mycommand.definition + "`""
                $Path = (Join-Path $Env:SystemRoot -ChildPath "\sysnative\WindowsPowerShell\v1.0\powershell.exe")
                Start-Process -FilePath $Path -ArgumentList $Arguments -Verb RunAs
                Write-Log -Message "Win32 workaround completed successfully, Running x64 powershell version" -Severity 2
                Exit
            }
            Else {
                Write-Log -Message "Running 32-bit Powershell on 32-bit OS, No Win32 workaround required" -Severity 2
            }
        }
        ## <Perform Post-Uninstallation tasks here>
        Show-InstallationProgress `
        -StatusMessage 'Uninstalling All Relevant Support Files and Info'
        
        ## <Perform Pre-Uninstallation tasks here>
        
        foreach($uninstallSupportFile in $supportFiles){
            if($uninstallSupportFile -eq '$true'){
                Write-Log -Message "Uninstalling $($uninstallSupportFile.name) $($uninstallSupportFile.file) $($uninstallSupportFile.args)" -Severity 1 -Source $deployAppScriptFriendlyName
                $uninstallAppList = Get-InstalledApplication -Name $uninstallSupportFile.name
                ForEach ($uninstallApp in $uninstallAppList){
                    #If uninstall string property exists
                    If($uninstallApp.UninstallString){

                        $extractJustPath = $uninstallApp.UninstallString -replace ' /.*$'
                        $UninstPath = $($extractJustPath).Replace('"','')
                        $UninstPath = $UninstPath.ToString()
                        switch -Regex ($UninstPath) {

                            # Matches a file path ending in '.exe' but not containing 'MsiExec.exe' or 'MsiExec'
                            '^(?!.*MsiExec).*\.exe.*$' { 
                                # Confirms path exists and is a file
                                If(Test-Path -Path $UninstPath){
                                    Write-Log -Message "Found $($uninstallApp.DisplayName) $($uninstallApp.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                                    Execute-Process -Path $UninstPath -Parameters $uninstallSupportFile.uninstallArgs -WaitForMsiExec -MsiExecWaitTime 240 -WindowStyle Hidden
                                    Start-Sleep -Seconds 20
                                }
                            }
                    
                            # Matches a file path ending in '.msi' or a string containing 'MsiExec' (with optional '.exe') followed by the uninstall command
                            '(\.msi$)|((?:.*\s)?MsiExec(?:\.exe)?\s+/X\{[A-F0-9-]+\})' { 
                                if((Test-Path -Path $UninstPath) -or ($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')){
                                    if(($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')){
                    
                                        # Find the index of the first opening brace and the closing brace
                                        $start = $inputString.IndexOf('{')
                                        $end = $inputString.IndexOf('}', $start)
                    
                                        # If both braces are found, extract the substring between them
                                        if ($start -ne -1 -and $end -ne -1) {
                                            $UninstPath = $inputString.Substring($start, $end - $start + 1)
                                        }

                                    }

                                    Write-Log -Message "Found $($uninstallApp.DisplayName) $($uninstallApp.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                                    Execute-MSI -Action 'Uninstall' -Path $UninstPath -Parameters $uninstallSupportFile.uninstallArgs
                                    Start-Sleep -Seconds 20
                                }
                            }
                    
                            default { 
                                Write-Log -Message "$($uninstallApp.DisplayName) $($uninstallApp.DisplayVersion) Couldn't Find a Valid Way to Uninstall. Please Uninstall Manually." -Severity 3 -Source $deployAppScriptFriendlyName
                            }
                        }
                    }
                }
            }
        }


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        # #* PRE-REPAIR - Note: if editing removal of block
        # guides make editing for you easier is easily 
        # done by replacing <#s#> and <#i#> with blank
        # everything should align properly.
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps $potentialClashApps -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        foreach($repairSupportFile in $supportFiles){

            Write-Log -Message "repairing $($repairSupportFile.name) $($repairSupportFile.file) $($repairSupportFile.args)" -Severity 1 -Source $deployAppScriptFriendlyName
            $repairAppList = Get-InstalledApplication -Name $repairSupportFile.name

            ForEach ($repairApp in $repairAppList){
                    
                #If repair string property exists
                If($App.UninstallString){

                    $extractJustPath = $App.UninstallString -replace ' /.*$'
                    $repairPath = $($extractJustPath).Replace('"','')
                    $repairPath = $repairPath.ToString()
                    switch -Regex ($repairPath) {
                <#s#>
                <#s#>  # Matches a file path ending in '.exe' but not containing 'MsiExec.exe' or 'MsiExec'
                <#s#>  '^(?!.*MsiExec).*\.exe$' { 
                <#s#> 
                <#s#>      # Confirms path exists and is a file
                <#s#>      If(Test-Path -Path $repairPath){
                <#s#>    <#i#> Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                <#s#>    <#i#> Execute-Process -Path $repairPath -Parameters $repairSupportFile.uninstallArgs -WindowStyle Hidden
                <#s#>    <#i#> Start-Sleep -Seconds 20
                <#s#>    <#i#>
                <#s#>    <#i#>#####################################################################
                <#s#>    <#i#>#
                <#s#>    <#i#># Install Logic for Support Files -
                <#s#>    <#i#># If you have support files to
                <#s#>    <#i#># repair, Come back later to
                <#s#>    <#i#># implent a better way to handle
                <#s#>    <#i#># repairs with processes
                <#s#>    <#i#>#
                <#s#>    <#i#>#####################################################################
                <#s#>    <#i#>## Check if there is anything in the support files folder or if there
                <#s#>    <#i#>## is a noted download location
                <#s#>    <#i#> $supportDirCheck = Test-Path -Path "$dirSupportFiles\*"
                <#s#>    <#i#>                                                               
                <#s#>    <#i#>## Check if the support files array has any download URLs
                <#s#>    <#i#> $checkSupportDownloadRequired = $supportFiles | `
                <#s#>    <#i#>        Where-Object { $_.downloadURL -like "*http*" }
                <#s#>    <#i#>                                                                   
                <#s#>    <#i#># # Set the support install path to the default support files folder,
                <#s#>    <#i#># # Provide logic for if there is a download URL, set the path to the 
                <#s#>    <#i#># # download folder
                <#s#>    <#i#> $supportInstallPath = $dirSupportFiles
                <#s#>    <#i#> Write-Log -Message "Checking Support Files Exist to Install" `
                <#s#>    <#i#>    -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>                                                   
                <#s#>    <#i#> If ($supportDirCheck -or $checkSupportDownloadRequired) {
                <#s#>    <#i#>                                                                           
                <#s#>    <#i#>    # Support files download location - do not modify unless you want to 
                <#s#>    <#i#>    # change where the files are downloaded to ensure the path always exists
                <#s#>    <#i#>    [String]$supportDownloadTempFolder = "$dirSupportFiles\Downloads"
                <#s#>    <#i#>    New-Item -ItemType Directory -Force -Path $supportDownloadTempFolder | Out-Null
                <#s#>    <#i#>                                                           
                <#s#>    <#i#>    # # Iterate through the supportFiles array and install each file 
                <#s#>    <#i#>    # #  keep track of index for referencing purposes
                <#s#>    <#i#>    Write-Log -Message ("Found $($supportFiles.Count) Support Files " `
                <#s#>    <#i#>        + "to Install") -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>
                <#s#>    <#i#>     Write-Log -Message "Installing $($repairSupportFile.name) $($repairSupportFile.file) $($repairSupportFile.args)" -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>     
                <#s#>    <#i#>     ## Check if the file should be downloaded 
                <#s#>    <#i#>     Write-Log -Message "Checking if $($repairSupportFile.file) should be downloaded" -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>     if ($repairSupportFile.downloadURL -like '*http*') {
                <#s#>    <#i#>         Write-Log -Message "Downloading $($repairSupportFile.name) $($repairSupportFile.file) from $($repairSupportFile.downloadURL)" -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>         # Make hash property a flat variable - just in case
                <#s#>    <#i#>         $downloadSupportFileName = $repairSupportFile.file
                <#s#>    <#i#>         (New-Object System.Net.WebClient).DownloadFile($repairSupportFile.downloadURL, "$supportDownloadTempFolder\$downloadFileName")
                <#s#>    <#i#>                                
                <#s#>    <#i#>         $supportInstallPath = $supportDownloadTempFolder
                <#s#>    <#i#>         Write-Log -Message "Downloaded $($repairSupportFile.name) $($repairSupportFile.file) to $($supportDownloadTempFolder)" -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>     }
                <#s#>    <#i#>                                                                                                        
                <#s#>    <#i#>     # Ensure the file exists/downloaded properly in the support
                <#s#>    <#i#>     # files folder
                <#s#>    <#i#>     Write-Log -Message "Checking if $($repairSupportFile.file) exists in $($supportInstallPath)" -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>     $supportFilePath = Get-ChildItem -Path "$supportInstallPath" -Include $repairSupportFile.file -File -Recurse -ErrorAction SilentlyContinue
                <#s#>    <#i#>     If ($supportFilePath.Exists) {
                <#s#>    <#i#>         Write-Log -Message "Found $($supportFilePath.FullName) in $($supportInstallPath)" -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>         ## Check if the file is an executable or an MSI and install accordingly
                <#s#>    <#i#>         $fileExtension = [System.IO.Path]::GetExtension($supportFilePath)
                <#s#>    <#i#>         switch ($fileExtension) {
                <#s#>    <#i#>             # Add to this list as needed
                <#s#>    <#i#>                                                                                            
                <#s#>    <#i#>             # If the file is an executable, install it
                <#s#>    <#i#>             ".exe" {
                <#s#>    <#i#>                 Write-Log -Message "Found $($supportFilePath.FullName) as an Executable, now attempting to install. For $appName pre-requisites."
                <#s#>    <#i#>                 Show-InstallationProgress "Installing $($supportFilePath.FullName) for $appName pre-requisites."
                <#s#>    <#i#>                 Execute-Process -Path $supportFilePath -Parameters $repairSupportFile.args -WaitForMsiExec -MsiExecWaitTime 240 -WindowStyle Hidden
                <#s#>    <#i#>             }
                <#s#>    <#i#>                                                                            
                <#s#>    <#i#>             # If the file is an MSI, install it
                <#s#>    <#i#>             ".msi" {
                <#s#>    <#i#>                 Write-Log -Message "Found $($supportFilePath.FullName) as an MSI, now attempting to install. For $appName pre-requisites."
                <#s#>    <#i#>                 Show-InstallationProgress "Installing $($supportFilePath.FullName) for $appName pre-requisites."
                <#s#>    <#i#>                 Execute-MSI -Action 'Install' -Path $supportFilePath -Parameters $repairSupportFile.args
                <#s#>    <#i#>             }
                <#s#>    <#i#>                                                                                                                
                <#s#>    <#i#>             # If the file is neither an executable or an MSI, log it and move on
                <#s#>    <#i#>             default {
                <#s#>    <#i#>                 Write-Log -Message "Unsupported file type: $fileExtension" -Severity 3 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>             }
                <#s#>    <#i#>         }
                <#s#>    <#i#>     }
                <#s#>    <#i#>     Else {
                <#s#>    <#i#>         Write-Log -Message "$($repairSupportFile.file) not found in SupportFiles folder" -Severity 3 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#>     }
                <#s#>    <#i#> }
                <#s#>    <#i#> Else {
                <#s#>    <#i#>    Write-Log -Message 'No Support Files Found - If support files are meant to exist, make sure they are in the support files folder before repackaging' -Severity 1 -Source $deployAppScriptFriendlyName
                <#s#>    <#i#> }
                <#s#>      }
                <#s#>  }
                <#s#>  # Matches a file path ending in '.msi'
                <#s#>   # or a string containing 'MsiExec' (with optional '.exe')
                <#s#>   # followed by the uninstall command
                <#s#>
                <#s#>
                <#s#>  '(\.msi$)|((?:.*\s)?MsiExec(?:\.exe)?\s+/X\{[A-F0-9-]+\})'{
                <#s#>
                <#s#>       if ((Test-Path -Path $UninstPath) -or ($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')) {
                <#s#>           if (($UninstPath -match 'MsiExec') -or ($UninstPath -match 'msiexec')) {
                <#s#>               # Find the index of the
                <#s#>               # first opening brace and
                <#s#>               # the closing brace
                <#s#>              $start = $inputString.IndexOf('{')
                <#s#>              $end = $inputString.IndexOf('}', $start)
                <#s#>
                <#s#>              # If both braces are found, extract the substring between them
                <#s#>              if ($start -ne -1 -and $end -ne -1) {
                <#s#>                  $repairPath = $inputString.Substring($start, $end - $start + 1)
                <#s#>              }
                <#s#>           }
                <#s#>           Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
                <#s#>           Execute-MSI -Action 'Repair' -Path $repairPath -Parameters '/fadcumsv /qn /passive /quiet'
                <#s#>           Start-Sleep -Seconds 20
                <#s#>       }
                <#s#>  }
                    }
                }
            }
        }
        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## <Perform Repair tasks here>
        $repairAppList = Get-InstalledApplication -Name $appName
        
        ForEach ($App in $AppList){
            #If repair string property exists
            If($App.UninstallString){

                $extractJustPath = $App.UninstallString -replace ' /.*$'
                $repairPath = $($extractJustPath).Replace('"','')
                $repairPath = $repairPath.ToString()
                switch -Regex ($repairPath) {
            <#s#>
            <#s#>  # Matches a file path ending in '.exe' but not containing 'MsiExec.exe' or 'MsiExec'
            <#s#>  '^(?!.*MsiExec).*\.exe$' { 
            <#s#> 
            <#s#>      # Confirms path exists and is a file
            <#s#>      If(Test-Path -Path $repairPath){
            <#s#>    <#i#> Write-Log -Message "Found" `
            <#s#>    <#i#> + " $($App.DisplayName) " `
            <#s#>    <#i#> + "$($App.DisplayVersion) " `
            <#s#>    <#i#> + "However I don't have " `
            <#s#>    <#i#> + "proper repair logic for" `
            <#s#>    <#i#> + " executable based repairs" `
            <#s#>    <#i#> + "yet so I'm just going to " `
            <#s#>    <#i#> + "uninstall and reinstall." `
            <#s#>    <#i#>    -Severity 1 `
            <#s#>    <#i#>    -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>    
            <#s#>    <#i#> Execute-Process -Path $repairPath `
            <#s#>    <#i#>    -Parameters $appUninstallerParams `
            <#s#>    <#i#>    -WaitForMsiExec `
            <#s#>    <#i#>    -MsiExecWaitTime 240 -WindowStyle Hidden
            <#s#>    <#i#> Start-Sleep -Seconds 20
            <#s#>    <#i#>
            <#s#>    <#i#>#####################################################################
            <#s#>    <#i#>#
            <#s#>    <#i#># Install Logic for Support Files -
            <#s#>    <#i#># If you have support files to
            <#s#>    <#i#># repair, Come back later to
            <#s#>    <#i#># implement a better way to handle
            <#s#>    <#i#># repairs with processes
            <#s#>    <#i#>#
            <#s#>    <#i#>#####################################################################
            <#s#>    <#i#>## Check if the support files array has any download URLs
            <#s#>    <#i#>$checkInstallDownloadRequired = $appDownloadUrl -like "*http*"
            <#s#>    <#i#>                
            <#s#>    <#i#>$appDirCheck = Test-Path -Path "$dirFiles\*"
            <#s#>    <#i#>$appDir = "$dirFiles\*"    
            <#s#>    <#i#>If ($appDirCheck -or $checkInstallDownloadRequired) {
            <#s#>    <#i#>    
            <#s#>    <#i#>    # Support files download location - do not modify unless you want to 
            <#s#>    <#i#>    # change where the files are downloaded to ensure the path always exists
            <#s#>    <#i#>    [String]$appDownloadTempFolder = "$appDir\Downloads"
            <#s#>    <#i#>    New-Item -ItemType Directory -Force -Path $appDownloadTempFolder | Out-Null
            <#s#>    <#i#>    
            <#s#>    <#i#>    Write-Log -Message "Checking if $appInstallerFile should be downloaded" -Severity 1 -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>    if ($checkInstallDownloadRequired) {
            <#s#>    <#i#>        Write-Log -Message "Downloading $appInstallerFile from $appDownloadUrl" -Severity 1 -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>        # Make hash property a flat variable - just in
            <#s#>    <#i#>        # case
            <#s#>    <#i#>        
            <#s#>    <#i#>        $downloadAppFileName = $appInstallerFile
            <#s#>    <#i#>        $appDirCheck = Test-Path -Path "$appDownloadTempFolder\*"
            <#s#>    <#i#>        $appDir = "$appDownloadTempFolder\*"
            <#s#>    <#i#>        if($appDirCheck){
            <#s#>    <#i#>          (New-Object System.Net.WebClient).DownloadFile($appDownloadUrl,"$appDownloadTempFolder\$downloadAppFileName")
            <#s#>    <#i#>          Write-Log -Message "Downloaded $appInstallerFile to $appDownloadTempFolder" -Severity 1 -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>        }
            <#s#>    <#i#>        
            <#s#>    <#i#>    }
            <#s#>    <#i#>    
            <#s#>    <#i#>    # Ensure the file exists/downloaded properly in the
            <#s#>    <#i#>    # standard Files sub-folder
            <#s#>    <#i#>    Write-Log -Message "Checking if $appInstallerFile exists in $appDir" -Severity 1 -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>    $appInstallerPath = Get-ChildItem -Path "$appDir" -Include $appInstallerFile -File -Recurse -ErrorAction SilentlyContinue
            <#s#>    <#i#>    If ($appInstallerPath.Exists) {
            <#s#>    <#i#>        Write-Log -Message "Found $($appInstallerPath.FullName) in $($appDir)" -Severity 1 -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>        ## Check if the file is an executable or an MSI and install accordingly
            <#s#>    <#i#>        $fileExtension = [System.IO.Path]::GetExtension($appInstallerPath)
            <#s#>    <#i#>        switch ($fileExtension) {
            <#s#>    <#i#>            # Add to this list as needed
            <#s#>    <#i#>                    
            <#s#>    <#i#>            # If the file is an executable, install it
            <#s#>    <#i#>            ".exe" {
            <#s#>    <#i#>                Write-Log -Message "Found $($appInstallerPath.FullName) as an Executable, now attempting to install. For $appName."
            <#s#>    <#i#>                Show-InstallationProgress "Installing $($appInstallerPath.FullName) for $appName."
            <#s#>    <#i#>                Execute-Process -Path $appInstallerPath -Parameters $appInstallerParams -WaitForMsiExec -MsiExecWaitTime 240 -WindowStyle Hidden
            <#s#>    <#i#>            }
            <#s#>    <#i#>
            <#s#>    <#i#>            # If the file is an MSI, install it
            <#s#>    <#i#>            ".msi" {
            <#s#>    <#i#>                Write-Log -Message "Found $($appInstallerPath.FullName) as an MSI, now attempting to install. For $appName."
            <#s#>    <#i#>                Show-InstallationProgress "Installing $($appInstallerPath.FullName) for $appName."
            <#s#>    <#i#>                Execute-MSI -Action 'Install' -Path $appInstallerPath -Parameters $appInstallerParams
            <#s#>    <#i#>            }
            <#s#>    <#i#>
            <#s#>    <#i#>            # If the file is neither an executable or an MSI, log it and move on
            <#s#>    <#i#>            default {
            <#s#>    <#i#>                Write-Log -Message "Unsupported file type: $fileExtension" -Severity 3 -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>            }
            <#s#>    <#i#>                    
            <#s#>    <#i#>        }
            <#s#>    <#i#>                                                                                                                                                                    
            <#s#>    <#i#>    }
            <#s#>    <#i#>    Else {
            <#s#>    <#i#>        Write-Log -Message "$appInstallerFile not found in Files folder" -Severity 3 -Source $deployAppScriptFriendlyName
            <#s#>    <#i#>    }
            <#s#>    <#i#>}
            <#s#>     }
                    }
            <#s#>
            <#s#>  # Matches a file path ending in '.msi' or a string containing 'MsiExec' (with optional '.exe') followed by the uninstall command
            <#s#>  '(\.msi$)|((?:.*\s)?MsiExec(?:\.exe)?\s+/X\{[A-F0-9-]+\})' { 
            <#s#>      if((Test-Path -Path $repairPath) -or ($repairPath -match 'MsiExec') -or ($repairPath -match 'msiexec')){
            <#s#>          if(($repairPath -match 'MsiExec') -or ($repairPath -match 'msiexec')){
            <#s#>
            <#s#>              # Find the index of the first opening brace and the closing brace
            <#s#>              $start = $inputString.IndexOf('{')
            <#s#>              $end = $inputString.IndexOf('}', $start)
            <#s#>
            <#s#>              # If both braces are found, extract the substring between them
            <#s#>              if ($start -ne -1 -and $end -ne -1) {
            <#s#>                  $repairPath = $inputString.Substring($start, $end - $start + 1)
            <#s#>              }
            <#s#>          }
            <#s#>          Write-Log -Message "Found $($App.DisplayName) $($App.DisplayVersion) and a valid uninstall string, now attempting to uninstall."
            <#s#>          Execute-MSI -Action 'Repair' -Path $repairPath -Parameters '/fadcumsv /qn /passive /quiet'
            <#s#>          Start-Sleep -Seconds 20
            <#s#>      }
                    }
            <#s#>
            <#s#>  default { 
            <#s#>      Write-Log -Message "$($App.DisplayName) $($App.DisplayVersion) Couldn't Find a Valid Way to Uninstall. Please Uninstall Manually." -Severity 3 -Source $deployAppScriptFriendlyName
                    }
                }        
            }
        }
        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

## Call the Exit-Script function to perform final cleanup operations
Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
