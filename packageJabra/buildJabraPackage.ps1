# buildJabraPackage.ps1

param (
    [string]$PackageFolder, # Specify the folder containing the files to be packaged
    [string]$OutputFolder,  # Specify the folder where the packaged file will be saved
    [switch]$Reset          # Reset parameters to default values
)


##################################################################
# The folder containing the files to be packaged

$DEPLOYMENT_PACKAGE_FOLDER = 'C:\IntunePrep\UserWizard\packageJabra\DeployPackageJabra\' #DoNotRemoveKeepThisHereAtAllTimes-IsTag

##################################################################
# The folder where the packaged file will be saved

$PACKAGE_OUTPUT_FOLDER = $PSScriptRoot #DoNotRemoveKeepThisHereAtAllTimes-IsTag

##################################################################
# have the win32 intune package builder tool installed
# If you already have unpacked the tool to a directory want
# to use that directory, set the following variable to the
# path to the directory containing the tool.

$WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL = 'C:\IntuneContentPrepTool\IntuneWinAppUtil.exe'

##################################################################
# If you don't have the tool installed, you can download it

$INTUNE_TOOL_DOWNLOAD_URL = 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/heads/master.zip'

##################################################################
# The directory where the tool will be downloaded to or is
# already

$DOWNLOAD_OR_WORKING_DIR = "$env:TEMP\IntuneContentPrepTool"

##################################################################
# The name of the tool in the ZIP file

$INTUNE_PACKAGING_FILENAME = 'IntuneWinAppUtil.exe'

##################################################################
# The possible name of the folder in the ZIP file

$POTENTIAL_ZIPPED_FOLDER = 'Microsoft-Win32-Content-Prep-Tool-master'

##################################################################
# The name of the PSADT file incase they change it

$PSADT_FILE = 'Deploy-Application.exe'

function Write-Log {
    param (
        [string]$Message,
        [string]$Path = "$PSScriptRoot\buildPackageLog.log" # Specify the log file path
    )
    $messageToLog = "$(Get-Date) - $Message"
    Write-Host $messageToLog
    Out-File -Append -FilePath $Path -InputObject $messageToLog
}
function Ensure-ExecutionPolicyIsUnrestricted {
    try {
        $currentPolicy = Get-ExecutionPolicy
        if ($currentPolicy -ine 'Unrestricted') {
            Write-Log "Current execution policy is '$currentPolicy'. Attempting to change to 'Unrestricted'..."
            try {
                Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force
            } catch {
                Write-Log "Failed to change the execution policy. At local machine - Could be already set to Bypass or Unrestricted. Trying at current user scope"   
            }
            try {
                Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force
            } catch {
                Write-Log "Failed to change the execution policy. At local machine - Could be already set to Bypass or Unrestricted. Trying at Process scope"   
            }
            Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force


            # Start a new instance of the script
            $scriptPath = $MyInvocation.MyCommand.Path
            Write-Log "Restarting script with updated execution policy..."
            Start-Process powershell.exe -ArgumentList "-File `"$scriptPath`"" -NoNewWindow

            # Exit the current script instance
            exit
        }
    }
    catch {
        Write-Error "An error occurred: $_. Cannot set execution policy or restart the script."
        # Handle the error or exit if necessary
        exit
    }
}

try {
    # Ensure the execution policy is Unrestricted
    Ensure-ExecutionPolicyIsUnrestricted

    # The rest of your script goes here
    Write-Log "Script execution continues with the appropriate execution policy..."
}
catch {
    Write-Error "An error occurred during script execution: $_"
    Exit
}

#Parameter validation
Write-Log "Validating if parameters were passed to the script"
if ($PackageFolder) { 
    Write-Log "PackageFolder parameter was passed to the script"
    Write-Log "PackageFolder: $PackageFolder"
    Write-Log "Deployment package folder will be set to $PackageFolder"
    Write-Log " "

    $DEPLOYMENT_PACKAGE_FOLDER = $PackageFolder 
    Write-Log "DEPLOYMENT_PACKAGE_FOLDER: $DEPLOYMENT_PACKAGE_FOLDER"
    Write-Log " "
}

if ($OutputFolder) { 
    Write-Log "PackageFolder parameter was passed to the script"
    Write-Log "PackageFolder: $OutputFolder"
    Write-Log "Deployment package folder will be set to $OutputFolder"
    Write-Log " "

    $PACKAGE_OUTPUT_FOLDER = $OutputFolder 
    Write-Log "PACKAGE_OUTPUT_FOLDER: $PACKAGE_OUTPUT_FOLDER"
    Write-Log " "
}

# Write to log all the static variables
Write-Log "Your Current Build Configuration"
Write-Log "=========================="
Write-Log "DEPLOYMENT_PACKAGE_FOLDER: $DEPLOYMENT_PACKAGE_FOLDER"
Write-Log "PACKAGE_OUTPUT_FOLDER: $PACKAGE_OUTPUT_FOLDER"
Write-Log "WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL: $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL"
Write-Log "INTUNE_TOOL_DOWNLOAD_URL: $INTUNE_TOOL_DOWNLOAD_URL"
Write-Log "DOWNLOAD_OR_WORKING_DIR: $DOWNLOAD_OR_WORKING_DIR"
Write-Log "INTUNE_PACKAGING_FILENAME: $INTUNE_PACKAGING_FILENAME"
Write-Log "POTENTIAL_ZIPPED_FOLDER: $POTENTIAL_ZIPPED_FOLDER"
Write-Log "=========================="
Write-Log " "
Write-Log "Checking if Download or Working directory exists"
Write-Log "If it doesn't exist, it will be created"

# Check if Download or Working directory exists - if not
# create it
if (Test-Path $DOWNLOAD_OR_WORKING_DIR) {
    Write-Log "Download or Working directory found at $DOWNLOAD_OR_WORKING_DIR"
} else {
    Write-Log "Download or Working directory not found at $DOWNLOAD_OR_WORKING_DIR"
    Write-Log "Creating Download or Working directory at $DOWNLOAD_OR_WORKING_DIR"
    New-Item -ItemType Directory -Force -Path $DOWNLOAD_OR_WORKING_DIR
}

Write-Log "Checking if the packaging tool exists"
# Test if $INTUNE_PACKAGING_FILENAME exists
if (Test-Path $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL) {
    Write-Log "$INTUNE_PACKAGING_FILENAME found at $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL"
} else {
    Write-Log "$INTUNE_PACKAGING_FILENAME not found at $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL"
    
    # Test if the INTUNE_TOOL_DOWNLOAD_URL is set to a valid URL
    if ($INTUNE_TOOL_DOWNLOAD_URL) {
        Write-Log "Downloading $INTUNE_PACKAGING_FILENAME from $INTUNE_TOOL_DOWNLOAD_URL"
        
        try {
            $downloadPath = "$DOWNLOAD_OR_WORKING_DIR\IntuneWinAppUtil.zip"
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($INTUNE_TOOL_DOWNLOAD_URL, $downloadPath)

            if (Test-Path $downloadPath) {
                Write-Log "Download successful"

                # Extract the $INTUNE_PACKAGING_FILENAME from the ZIP file
                Expand-Archive -Path $downloadPath -DestinationPath $DOWNLOAD_OR_WORKING_DIR -Force

                $ExtractedPath1 = "$DOWNLOAD_OR_WORKING_DIR\$POTENTIAL_ZIPPED_FOLDER\$INTUNE_PACKAGING_FILENAME"
                $ExtractedPath2 = "$DOWNLOAD_OR_WORKING_DIR\$INTUNE_PACKAGING_FILENAME"

                # Verify if the $INTUNE_PACKAGING_FILENAME was extracted
                if (Test-Path $ExtractedPath1) {
                    Write-Log "$INTUNE_PACKAGING_FILENAME extracted to $ExtractedPath1"
                    $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL = "$ExtractedPath1"
                } elseif (Test-Path $ExtractedPath2) {
                    Write-Log "$INTUNE_PACKAGING_FILENAME extracted to $ExtractedPath2"
                    $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL = "$ExtractedPath2"
                } else {
                    Write-Log "$INTUNE_PACKAGING_FILENAME not extracted to $DOWNLOAD_OR_WORKING_DIR"
                    Write-Log "Exiting script"
                    Exit
                }
            } else {
                Write-Log "Download failed. File not found at $downloadPath"
                Write-Log "Exiting script"
                Exit
            }
        } catch {
            Write-Log "An error occurred during download: $_"
            Write-Log "Exiting script"
            Exit
        }
    } else {
        Write-Log "INTUNE_TOOL_DOWNLOAD_URL not set to a valid URL"
        Write-Log "Set either $INTUNE_TOOL_DOWNLOAD_URL or $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL to a valid value"
        Write-Log "Exiting script"
        Exit
    }
}

Write-Log "Packaging tool exists"
Write-Log "Packaging the files in $DEPLOYMENT_PACKAGE_FOLDER"
Write-Log "The packaged file will be saved to $PACKAGE_OUTPUT_FOLDER"

Start-Process -FilePath $WIN32_CONTENT_PREP_INTUNE_PACKAGE_TOOL -ArgumentList @(
    '-c', $DEPLOYMENT_PACKAGE_FOLDER,
    '-s', $PSADT_FILE,
    '-o', $PACKAGE_OUTPUT_FOLDER,
    '-q'
) -Wait

# Rename intunewin file to match the name of the folder
# containing the files to be packaged

Write-Log "Renaming the intunewin file to match the name of the folder containing the files to be packaged"

# Find the .intunewin file in the output folder
Write-Log "Finding the .intunewin file in the output folder"
if ($PSADT_FILE.EndsWith('.exe')) {
    $PSADT_FullName = $PSADT_FILE.Substring(0, $PSADT_FILE.Length - 4)
} else {
    Write-Log "The PSADT file source doesn't end with .exe"
    Write-Log "Something has change with PSADT"
    Write-Log "Exiting script"
    Exit
}
$intuneWinfile = $PSADT_FullName + '.intunewin'
# Get the name of the last folder in the
# $DEPLOYMENT_PACKAGE_FOLDER path
Write-Log "Getting the name of the last folder in the $DEPLOYMENT_PACKAGE_FOLDER path"
$lastFolderName = Split-Path -Path $DEPLOYMENT_PACKAGE_FOLDER -Leaf

# Construct the new file name using the last folder name
Write-Log "Constructing the new file name using the last folder name"
$intuneWinFileNewName = "$PACKAGE_OUTPUT_FOLDER\$lastFolderName.intunewin"

$version = 0
for (; Test-Path $intuneWinFileNewName; $version++) {
    Write-Log "The file $intuneWinFileNewName already exists"
    Write-Log "Adding a version number to the end of the file name"
    
    $intuneWinFileNewName = "$PACKAGE_OUTPUT_FOLDER\$lastFolderName-V$($version + 1).intunewin"
}

# Rename the file
Write-Log "Renaming the file"
Write-Log "Old name: $intuneWinFile"
Write-Log "New name: $intuneWinFileNewName"
Write-Log "Used Path parameter to force rename with"

Rename-Item -Path $intuneWinFile -NewName $intuneWinFileNewName -Force
# Thescriptwillbeupdated
# Make parameter default if it was passed
# Define the pattern to match the block to ignore
$ignorePattern = '(# Thescriptwillbeupdated.*?# Thisistheendofthechecks)'
# Thescriptwillbeupdated
if ($PackageFolder) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptContent = Get-Content $scriptPath -Raw

    if (-not [string]::IsNullOrWhiteSpace($scriptContent)) {
        # Define a pattern that uniquely identifies the variable assignment lines
        # Use a placeholder pattern that matches the intended lines, including a unique comment for identification
        $DeployPattern = "\`$DEPLOYMENT_PACKAGE_FOLDER = '.*?' #DoNotRemoveKeepThisHereAtAllTimes-IsTag"
        
        # Form the replacement string with the new value and the unique comment
        # Ensure the placeholder `$PackageFolder` is dynamically inserted
        $DeployReplacement = "`$DEPLOYMENT_PACKAGE_FOLDER = '$PackageFolder' #DoNotRemoveKeepThisHereAtAllTimes-IsTag"
        
        # Split the script content around the ignored block
        $deploySegments = $scriptContent -split $ignorePattern, -1, 'Singleline'

        # Apply replacements to segments[0] and segments[4] if exists
        # Assuming your ignorePattern for replacements is correctly defined
        # Note: This example does not re-apply your specific replacement logic for simplicity
        if ($deploySegments.Length -gt 1) {
            $deploySegments[0] = $deploySegments[0] -replace $DeployPattern, $DeployReplacement
            if ($deploySegments.Length -gt 4) {
                $deploySegments[4] = $deploySegments[4] -replace $DeployPattern, $DeployReplacement
            }
        }

        # Reassemble the script content, ensuring the ignored block remains unchanged
        $newScriptContent = $deploySegments -join ''

        if (-not [string]::IsNullOrWhiteSpace($newScriptContent)) {
            $newScriptContent | Set-Content $scriptPath
            Write-Host "Script updated successfully."
        }
        else {
            Write-Host "Error: Replacement resulted in empty content."
        }
    }   
}

if ($OutputFolder) {
    # Update script with new default output folder
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptContent = Get-Content $scriptPath -Raw

    if (-not [string]::IsNullOrWhiteSpace($scriptContent)) {
        # Define a pattern that uniquely identifies the variable assignment lines
        # Use a placeholder pattern that matches the intended lines, including a unique comment for identification
        $packagePattern = "\`$PACKAGE_OUTPUT_FOLDER = '.*?' #DoNotRemoveKeepThisHereAtAllTimes-IsTag"
        
        # Form the replacement string with the new value and the unique comment
        # Ensure the placeholder `$OutputFolder` is dynamically inserted
        $packageReplacement = "`$PACKAGE_OUTPUT_FOLDER = '$OutputFolder' #DoNotRemoveKeepThisHereAtAllTimes-IsTag"
        
        # Split the script content around the ignored block
        $packageSegments = $scriptContent -split $ignorePattern, -1, 'Singleline'

        # Apply replacements to segments[0] and segments[4] if exists
        # Assuming your $pattern for replacements is correctly defined
        # Note: This example does not re-apply your specific replacement logic for simplicity
        if ($packageSegments.Length -gt 1) {
            $packageSegments[0] = $packageSegments[0] -replace $packagePattern, $packageReplacement
            if ($packageSegments.Length -gt 4) {
                $packageSegments[4] = $packageSegments[4] -replace $packagePattern, $packageReplacement
            }
        }

        # Reassemble the script content, ensuring the ignored block remains unchanged
        $newScriptContent = $packageSegments -join ''

        if (-not [string]::IsNullOrWhiteSpace($newScriptContent)) {
            $newScriptContent | Set-Content $scriptPath
            Write-Host "Script updated successfully."
        }
        else {
            Write-Host "Error: Replacement resulted in empty content."
        }
    } 
}

if ($reset) {
    # Update script with new default output folder
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptContent = Get-Content $scriptPath -Raw
    $rootStringed = '$PSScriptRoot'

    if (-not [string]::IsNullOrWhiteSpace($scriptContent)) {
        # Define a pattern that uniquely identifies the variable assignment lines
        # Use a placeholder pattern that matches the intended lines, including a unique comment for identification
        $resetPattern = "\`$PACKAGE_OUTPUT_FOLDER = '.*?' #DoNotRemoveKeepThisHereAtAllTimes-IsTag"
        
        # Form the replacement string with the new value and the unique comment
        # Ensure the placeholder `$OutputFolder` is dynamically inserted
        $resetReplacement = "`$PACKAGE_OUTPUT_FOLDER = '$rootStringed' #DoNotRemoveKeepThisHereAtAllTimes-IsTag"
        
        # Split the script content around the ignored block
        $resetSegments = $scriptContent -split $ignorePattern, -1, 'Singleline'

        # Apply replacements to segments[0] and segments[4] if exists
        # Assuming your $pattern for replacements is correctly defined
        # Note: This example does not re-apply your specific replacement logic for simplicity
        if ($resetSegments.Length -gt 1) {
            $resetSegments[0] = $resetSegments[0] -replace $resetPattern, $resetReplacement
            if ($resetSegments.Length -gt 4) {
                $resetSegments[4] = $resetSegments[4] -replace $resetPattern, $resetReplacement
            }
        }

        # Reassemble the script content, ensuring the ignored block remains unchanged
        $newScriptContent = $resetSegments -join ''

        if (-not [string]::IsNullOrWhiteSpace($newScriptContent)) {
            $newScriptContent | Set-Content $scriptPath
            Write-Log "Updated script with new default output folder: $rootStringed"
        }
        else {
            Write-Log "Error: Replacement resulted in empty content."
        }
    }
}

# Thisistheendofthechecks
# The above tag is what the script uses to know where to
# start updating again. If you change the tag, you will
# need to change the pattern to match the new tag
# Open the output folder
Write-Log "Opening the output folder"

# Assuming $intuneWinFileNewName contains the full path of the .intunewin file
$filePath = $intuneWinFileNewName

# Construct the command to open the folder and highlight the file
$command = "explorer.exe /select,""" + $filePath + """"

# Execute the command
Invoke-Expression $command

# Copy the output folder path to the clipboard
Write-Log "Copying the output folder path to the clipboard"
Set-Clipboard -Value $PACKAGE_OUTPUT_FOLDER

#Confirm the output file name
Write-Log "The name of the package is $intuneWinFileNewName"

# Optional: Notify the user
Write-Log "The output folder ($PACKAGE_OUTPUT_FOLDER) has been opened and its path copied to the clipboard."

# Ask the user if they want to remove the logs
Write-Log "Do you want to remove the logs? (Y/N)"
Write-Log ""
$userInput = Read-Host -Prompt "If you don't want to remove the logs, press N or No"

# Normalize the input to lower case for easier comparison
$normalizedInput = $userInput.ToLower()

# Check the user's input and act accordingly
if ($normalizedInput -in 'n', 'no', 'false') {
    Write-Host "Logs not removed."
} else {
    $logFilePath = "$PSScriptRoot\buildPackageLog.log"

    # Check if the log file exists
    if (Test-Path $logFilePath) {
        # Attempt to remove the log file
        try {
            Remove-Item -Path $logFilePath -ErrorAction Stop
            Write-Host "Log file removed successfully."
        } catch {
            # If an error occurs, log the message
            Write-Log "Failed to remove log file: $_"
        }
    } else {
        Write-Host "Log file does not exist, so it was not removed."
    }
}

# Read-Host -Prompt "Press Enter to exit"
