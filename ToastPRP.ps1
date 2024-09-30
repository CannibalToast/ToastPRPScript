param(
    [switch]$Debug
)

if ($Debug) {
    Write-Host "Debug mode enabled" -ForegroundColor Yellow
    Set-PSReadLineOption -ContinuationPrompt "=> "
}
Add-Type -AssemblyName System.Windows.Forms
$script:regkey = 'HKLM:\Software\Wow6432Node\Bethesda Softworks\Fallout4'
if (!(Test-Path 'HKLM:\Software\Wow6432Node\Bethesda Softworks\Fallout4')) { 
    Write-Error "Registry key for Fallout 4 could not be found, please run the fallout 4 launcher executable before trying to run this script again."
    return
}
$script:fo4 = Get-ItemPropertyValue -Path $script:regkey -Name 'installed path' -ErrorAction Stop
$script:data = Join-Path $fo4 "data"
$script:CK = "ckpe_loader.exe", "f4ck_loader.exe", "creationkit.exe" | Where-Object { Test-Path $_ } | Select-Object -First 1
$script:Archive2 = Join-Path $script:data "tools\archive2\archive2.exe"
$script:previsESP = Join-Path $script:data "PreVis.esp"
$script:PrevisDIR = Join-Path $script:data "vis"
$script:CombinedESP = Join-Path $script:data "CombinedObjects.esp"
$script:workingdir = Join-Path $script:data "workingdir"
$script:Meshesdir = Join-Path $script:data "Meshes"
$script:jsonFileName = "ToastPRP.json"
$script:jsonFilePath = Join-Path $script:fo4 $script:jsonFileName
$script:bsarch = Join-Path $script:fo4 "bsarch.exe"
$script:done = { Write-Host "Done!" -ForegroundColor Green }

#PEBKAC
if ((Get-ChildItem -Path (Join-Path $script:Meshesdir "Precombined") -ErrorAction SilentlyContinue) -or (Get-ChildItem -Path $script:workingdir -ErrorAction SilentlyContinue)) {
    Write-Host "[UNKNOWN PRECOMBINED FILES DETECTED]" -ForegroundColor Red
    Write-Output "This may be due currently loaded mods which have unpacked precombines, or leftover files from previous script failure(s)."
    Write-Host "THIS WILL MOST LIKELY CAUSE ISSUES DOWN THE LINE, HEED THIS WARNING!!!!" -ForegroundColor Red
    $script:yn = Read-Host "Do you wish to continue(Y) or close the script(N)?"
    If ($yn -eq "n") {
        Write-Host "Please find the origin of these files and either pack them into an archive or remove them to prevent any issues during generation." -ForegroundColor Red
        if ($host.Name -eq "ConsoleHost") {
            Stop-Transcript
            exit
        }
        else { exit }
    }
}

function Rename-Texture {
    param (
        [string]$Caller,
        [switch]$BA2, # Parameter to indicate conversion to .ba2
        [switch]$BA22, # Parameter to indicate conversion to .ba22
        [switch]$SkipRename,
        [switch]$Wait    # Parameter to indicate if the function should wait for renaming to complete
    )

    if ($SkipRename) {
        Write-output "Skipping file renaming due to SkipRename flag."
        return
    }

    if ($BA2 -and $BA22) {
        Write-Error "Cannot convert both ways simultaneously. Choose either -BA2 or -BA22."
        return
    }

    switch ($true) {
        $BA2.IsPresent {
            $sourceFileType = ".ba22"
            $targetFileType = ".ba2"
        }
        $BA22.IsPresent {
            $sourceFileType = ".ba2"
            $targetFileType = ".ba22"
        }
        default {
            Write-Error "No conversion direction specified. Use either -BA2 or -BA22."
            return
        }
    }

    # Define the regex pattern for specific files and patterns
    $specificFilesPattern = "^DLC.* - Textures.*$"
    $ccPattern = "^cc.* - Textures.*$"
    $fallout4Pattern = "^Fallout4 - Textures*.*$"
    $voicesPattern = "^(Fallout4|DLC.*|cc.*) - Voices.*$"  # Added pattern for Voices

    # Get all relevant files
    $sourceFiles = Get-ChildItem -Path $script:data -Filter "*$sourceFileType" -Recurse -File | Where-Object {
        $_.Name -match $specificFilesPattern -or $_.Name -match $ccPattern -or $_.Name -match $fallout4Pattern -or $_.Name -match $voicesPattern
    }

    if (-not $sourceFiles) {
        Write-output "No $sourceFileType files found. Skipping renaming."
        return
    }

    try {
        Write-output "Converting files to $targetFileType..."
        $sourceFiles | ForEach-Object {
            $newName = $_.BaseName + $targetFileType
            Rename-Item -Path $_.FullName -NewName $newName
        }
        Write-output "Conversion completed successfully."

        if ($Wait) {
            Write-output "Waiting for renaming operations to complete..."
            # Wait for all renaming operations to complete
            while ($true) {
                $remainingFiles = Get-ChildItem -Path $script:data -Filter "*$sourceFileType" -Recurse -File | Where-Object {
                    $_.Name -match $specificFilesPattern -or $_.Name -match $ccPattern -or $_.Name -match $fallout4Pattern -or $_.Name -match $voicesPattern
                }
                if (-not $remainingFiles) {
                    break
                }
                Start-Sleep 1
            }
            Write-output "All renaming operations completed."
        }
    }
    catch {
        Write-Error "An error occurred while converting files: $_"
        Write-output "Please ensure that you have the necessary permissions to rename files and that the files are not in use by another process."
        Write-output "Aborting script execution."
        exit 1
    }
}

if (!('WindowHelper' -as [Type])) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Text;

    public struct INPUT
    {
        public uint Type;
        public KEYBDINPUT Data;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    public class WindowHelper {
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    }
"@
}

function QueryESP {
    if ((Test-Path $script:bsarch) -and ($scriptPath -eq (Join-Path $script:fo4 (Split-Path $PSCommandPath -Leaf)))) { 
        Write-Host "All Systems Green" -ForegroundColor Green
        if ($Debug) {
            Write-Host $script:bsarch
            Write-host $scriptPath
        }
    }
    else {
        Wite-Host "Something went wrong during script setup. Either this script is not in the fallout 4 directory or bsarch is labeled in the .json file as used and the bsarch executable could not be found. Please fix these errors before attempting another run of this script." -ForegroundColor Red
        return
    }

    if (!(Test-Path "$script:data\$mod")) {
        Write-Output "Performing backup for: $ESP"
    }
    else {
        $useOwnEsp = Read-Host "Are you using your own .esp file? (IF NOT PRESS `N` TO PATCH ALL LOADED PLUGINS) (y/n)"
        switch ($useOwnEsp) {
            "y" {
                $prompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                    InitialDirectory = $script:data
                    Filter           = "Elder Scrolls Plugin (*.esp)|*.esp"
                }
                if ($prompt.ShowDialog() -eq 'OK') {
                    $script:ESP = [System.IO.Path]::GetFileNameWithoutExtension($prompt.FileName) + ".esp"
                    if (![string]::IsNullOrEmpty($script:ESP)) {
                        Write-Output "Performing backup for: $script:ESP"
                    }
                }
            }
            "n" {
                $pluginprompt = Read-Host "
Please select one of the following:
1. patch all loaded plugins?
2. patch one specific plugin?
3. don't patch anything (quit)?"
                switch ($pluginprompt) {
                    "1" {
                        Write-output "Patching all loaded plugins"
                        $script:mod = "$null"
                        $script:ESP = "$null"
                        $script:pas = "FO4Check_PreVisbines.pas"  # Ensure the .pas file is set
                        Invoke-xEdit -caller 'QueryESP'
                    }
                    "2" {
                        Write-output "What ESP file would you like to patch?"
                        $prompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                            InitialDirectory = $script:data
                            Filter           = "Elder Scrolls Plugin (*.esp; *.esl; *.esm)|*.esp; *.esl; *.esm"
                        }
                        if ($prompt.ShowDialog() -eq 'OK') {
                            $script:mod = [System.IO.Path]::GetFileName($prompt.FileName)
                            $script:ESP = "ToastPRP-" + [System.IO.Path]::GetFileNameWithoutExtension($prompt.FileName) + ".esp"
                            if (![string]::IsNullOrEmpty($script:mod)) {
                                Write-Output "Patching ESP: $script:mod"
                                $script:pas = "FO4Check_PreVisbines.pas"
                                $modArgument = "`"$script:mod`""  # Properly quote the mod argument
                                Write-output "Calling Invoke-xEdit with caller='QueryESP' and mod='$modArgument'"
                                Invoke-xEdit -caller 'QueryESP' -mod $script:mod
                            }
                        }
                    }
                    "3" {
                        $script:ESP = $null
                        Write-Output "Goodbye!"
                        exit
                    }
                }
            }
        }
        $script:EXT = [System.IO.Path]::GetFileNameWithoutExtension($script:ESP)
        $script:PSG = "$script:data\$($script:EXT) - Geometry.psg"
        $script:CSG = "$script:data\$($script:EXT) - Geometry.csg"
        if ($Debug) {
            # Debugging output UNCOMMENT TO USE
            Write-Debug "ESP: $script:ESP"
            Write-Debug "EXT: $script:EXT"
            Write-Debug "PSG: $script:PSG"
            Write-Debug "CSG: $script:CSG"
        }
    }
    # Create a unique folder for this attempt
    $logFolder = Join-Path $script:data "ToastPRP\Logs\"
    if (!(Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
    }
    $mainLogPath = "$script:data\ToastPRP\Logs\$script:EXT-{0:MM-dd-yyyy-HH-mm}.log" -f (Get-Date)
    Start-Transcript -Path $mainLogPath
    # Define the log file path for this attempt
    $script:logPath = "$logFolder"
    if (Test-Path *pack*.log){
        Remove-Item *pack*.log -Force -ErrorAction SilentlyContinue
        Write-Output "Removing undeleted orphan logs in path"
    }
}

function Invoke-xEdit {
    param (
        [string]$caller,
        [string]$mod = $null
    )
    if ($Debug) {
        # Debugging output UNCOMMENT TO USE
        Write-output "Caller: $caller"
        Write-output "Mod: $mod"
        Write-output "ESP: $script:ESP"
        Write-output "xEdit: $xEdit"
        Write-output "Script: $script:pas"
    }
    switch ($caller) {
        'QueryESP' {
            if ($mod) {
                # Handle the case where $caller is 'QueryESP' and $mod is not null
                $modWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($mod)
                $modWithEspExtension = "ToastPRP-$modWithoutExtension.esp"
                $scriptArgument = "-script:`"$script:pas`" -Full -nobuildrefs -Mod:`"$mod`" -seed:`"$modWithEspExtension`""
                if ($debug) { Write-output "Argument is $scriptArgument" }  # Debugging output
                $KeysToSend = "Enter"
            }
            else {
                # Handle the case where $caller is 'QueryESP' but $mod is null
                $scriptArgument = "-script:`"$script:pas`" -Full -nobuildrefs"
                $KeysToSend = "Enter"
            }
        }
        default {
            $scriptArgument = "-script:`"$script:pas`" -nobuildrefs -Mod:`"$script:ESP`""
            $KeysToSend = "PageDown", "Space", "Enter"
        }
    }

    if ($debug) { Write-output "Argument is $scriptArgument" }
    $xEditProcess = Start-Process -FilePath $xEdit -ArgumentList $scriptArgument -PassThru -NoNewWindow
    Start-Sleep 3

    if ($KeysToSend) {
        Keypress -KeysToSend $KeysToSend
    }

    # Initialize flags
    $script:firstFO4ScriptDetected = $false
    $script:seenApplyingScript = $false
    $script:alreadyReportedApplyingScript = $false
    $script:exitLoop = $false  # Flag to control the outer loop

    while ($true) {
        $title = New-Object System.Text.StringBuilder 256
        [WindowHelper]::GetWindowText($xEditProcess.MainWindowHandle, $title, $title.Capacity) | Out-Null
        $title = $title.ToString()

        switch -Regex ($title) {
            "FO4Script" {
                if ($seenApplyingScript) {
                    # Only act if "Applying script" has been seen before
                    Write-Output "xEdit script completed, closing..."
                    Write-Output "xEdit closed:"
                    Start-Sleep -Seconds 2 # Adjust countdown as needed
                    $xEditProcess.CloseMainWindow()
                    $xEditProcess.WaitForExit()
                    $exitLoop = $true  # Set flag to exit the loop
                    break  # This breaks out of the switch, but we need to exit the while loop too
                }
                else {
                    $firstFO4ScriptDetected = $true
                    if ($Debug) {
                        Write-Output "$title"
                    }
                }
            }
            "Applying script" {
                if (-not $alreadyReportedApplyingScript) {
                    # Ensure this message is only shown once per applying phase
                    Write-Output "Waiting for script completion" 
                    $seenApplyingScript = $true
                    $alreadyReportedApplyingScript = $true
                }
            }
        }

        if ($exitLoop) {
            break  # Breaks the while loop if $exitLoop is set to $true
        }
    }
}

function Invoke-CK ([string]$Argument) {
    if ($Debug) {
        # Table of arguments for debugging
        $argumentsTable = 
        "
    _____________________________________________________________
    | Function       | Argument                                 |
    |----------------|-----------------------------------       |
    | Precombines    | -GeneratePrecombined:`"$script:ESP`"     |
    | PSGCompression | -CompressPSG:`"$script:ESP`"             |
    | GenerateCDX    | -buildcdx:`"$script:ESP`"                |
    | Previs         | -GeneratePreVisdata:`"$script:ESP`"      |
    ￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣￣
    "
    
        Write-Debug $argumentsTable
    }
    # Switch statement to handle different arguments
    switch ($Argument) {
        "Precombines" {
            Rename-Texture -ba2
            $ckArgument = "-GeneratePrecombined:`"$script:ESP`" clean all"
            $script:pas = "Batch_FO4MergeCombinedObjectsAndCheck.pas"
        }
        "PSGCompression" {
            Rename-Texture -ba22
            Write-Output "Compressing PSG..."
            $ckArgument = "-CompressPSG:`"$script:ESP`""
            Wait-Process "ckpe_loader" -ErrorAction SilentlyContinue
        }
        "GenerateCDX" {
            Write-Output "Generating Cell Index (CDX)..."
            $ckArgument = "-buildcdx:`"$script:ESP`""
        }
        "Previs" {
            Rename-Texture -ba2
            Write-Output "Generating Previs Data..."
            $ckArgument = "-GeneratePreVisdata:`"$script:ESP`" clean all"
            $script:pas = "Batch_FO4MergePreVisandCleanRefr.pas"
        }
        default {
            Write-Error "Unknown argument: $Argument"
            return
        }
    }

    if ($debug) { Write-Output "Starting Creation Kit with arguments: $ckArgument" }
    $startTime = Get-Date
    Start-Process -FilePath $script:CK -ArgumentList $ckArgument -Wait
    
    Write-Output "Completed in $(New-TimeSpan -Start $startTime -End (Get-Date))."
}
#PEBKAC 
function Keypress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet("PageDown", "Space", "Enter")]
        [String[]]$KeysToSend
    )

    # Send each key in the array
    foreach ($Key in $KeysToSend) {
        switch ($Key) {
            "PageDown" { [System.Windows.Forms.SendKeys]::SendWait("{PGDN}") }
            "Space" { [System.Windows.Forms.SendKeys]::SendWait(" ") }
            "Enter" { [System.Windows.Forms.SendKeys]::SendWait("{ENTER}") }
        }

        # Wait for 100 milliseconds after each keypress
        Start-Sleep -Milliseconds 100
    }
}
#PEBKAC
function Wait-ForFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [int]$TimeoutSeconds = 60,
        [string]$Caller
    )
    
    $filePath = $FileName
    
    if (!(Test-Path -Path $script:data)) {
        Write-Error "Base directory $script:data does not exist."
        return
    }
    
    Write-output "Waiting for $filePath to appear..."
    
    $startTime = Get-Date
    $fileFound = $false
    $pollInterval = 100  # Start with a short initial poll interval (milliseconds)

    do {
        $fileExists = Test-Path $filePath
        if ($fileExists) {
            $fileFound = $true
            break
        }
        
        $elapsedTime = (Get-Date) - $startTime
        if ($elapsedTime.TotalSeconds -ge $TimeoutSeconds) {
            Write-Warning "Timeout reached while waiting for $FileName to appear."
            break
        }

        Start-Sleep -Milliseconds $pollInterval
        $pollInterval *= 2  # Gradually increase the poll interval to reduce system load
    } while ($true)
    
    if ($fileFound) {
        Write-output "File found: $filePath"
        # Caller-specific actions
        switch ($Caller) {
            'PSGCompression' {
                Remove-Item $script:PSG
            }
            'Precombines' {
                Write-output "Calling Invoke-xEdit with caller='Precombines' and mod='$SelectedFile'"
                Invoke-xEdit -caller 'Precombines'  # Moved before removing CombinedObjects.esp
                if (Test-Path $script:CombinedESP) {
                    Remove-Item $script:CombinedESP
                }
                else {
                    Write-output "$combinedESP not found. Exiting..."
                    Exit
                }
            }
            'CreateZIP' {
                Remove-Item $filesToCompress
            }
            # Add more cases as needed
            default {
                if ($debug) { Write-Output "No action taken for caller: $Caller" }
            }
        }
    }
    else {
        Write-Error "File $FileName not found within the timeout period."
    }
}
#PEBKAC
function Backup-ESP { 
    $backupPath = "$script:data\ToastPRP\ESP_Backups"
    
    # Ensure the backup directory exists
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    
    # Construct the backup file path using only the name of the ESP file
    $backupFilePath = Join-Path -Path $backupPath -ChildPath $ESP
    
    # Copy the ESP file to the backup directory
    $oldFilePath = Join-Path -Path $script:data -ChildPath $ESP
    try {
        Copy-Item -LiteralPath "$oldFilePath" -Destination "$backupFilePath" -Force -ErrorAction Stop
        Write-Output "Backup of $ESP created in $backupPath"
    }
    catch {
        Write-Error "Backup of $ESP failed: $_"
    }
}
function ManageJson {
    param (
        [switch]$CalledByPrecombines
    )

    try {
        $jsonFilePath = Join-Path $script:fo4 $script:jsonFileName
        
        $jsonContent = if (Test-Path $jsonFilePath) {
            Get-Content $jsonFilePath -Raw | ConvertFrom-Json
        }
        else {
            @{
                'ESP-WIP'    = @()
                'xEdit'      = $null
                'Bsarch'     = $false
                'BsarchPath' = $null
            }
        }

        if (-not $jsonContent.xEdit) {
            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Title = "Select FO4Edit file"
            $fileDialog.Filter = "FO4Edit (*.exe)|FO4Edit.exe;FO4Edit64.exe;fo4edit.exe;xEdit.exe;xEdit64.exe"
            
            if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $selectedFile = $fileDialog.FileName
                if ($selectedFile -match '(?i)(fo4edit|fo4edit64|xedit|xedit64)\.exe$') {
                    $jsonContent.xEdit = $selectedFile
                    $script:xEdit = $selectedFile
                }
            }
        }

        if ($CalledByPrecombines -and $script:ESP -and ($script:ESP -notin $jsonContent.'ESP-WIP')) {
            $jsonContent.'ESP-WIP' += $script:ESP
        }

        if (Test-Path $script:bsarch) {
            $jsonContent.Bsarch = $true
            $jsonContent.BsarchPath = $script:bsarch
        }
        else {
            $jsonContent.Bsarch = $false
            $jsonContent.BsarchPath = $null
        }

        $jsonString = $jsonContent | ConvertTo-Json -Depth 100
        Set-Content $jsonFilePath -Value $jsonString

        $script:xEdit = $jsonContent.xEdit
        $script:BSArchive = $jsonContent.BsarchPath

        return $jsonContent
    }
    catch {
        Write-Output "Error managing JSON file: $_"
    }
}

#PEBKAC
function DLBSArch {
    param (
        [string]$BsarchUrl = "https://github.com/TES5Edit/TES5Edit/raw/dev/Tools/BSArchive/bsarch.exe",
        [string]$PredefinedChecksum = "fb37aa274fa3756756012644c9fe8636"
    )

    # Helper function to download bsarch.exe and validate checksum
    function DownloadAndValidateBsarch {
        Invoke-WebRequest -Uri $BsarchUrl -OutFile $script:bsarch
        $hash = (Get-FileHash $script:bsarch -Algorithm MD5).Hash
        if ($hash -eq $PredefinedChecksum) {
            Write-output "bsarch.exe downloaded and validated successfully."
            return $true
        }
        else {
            Write-output "Downloaded bsarch.exe failed checksum validation. Either download failed or the executable was updated on the github repo."
            Remove-Item -Path $script:bsarch -ErrorAction SilentlyContinue
            return $false
        }
    }

    # Check if bsarch.exe exists and validate checksum, download if necessary
    if (!(Test-Path $script:bsarch) -or -not (DownloadAndValidateBsarch)) {
        Write-output "Attempting to download and validate bsarch.exe..."
        if (!(DownloadAndValidateBsarch)) {
            Write-output "Failed to obtain a valid bsarch.exe after download attempt. Please check the source or try again later."
            return
        }
    }

    Write-Host "BSArch validated" -ForegroundColor Green

    # Update the JSON content with the bsarch path if it has changed
    $jsonContent = ManageJson
    if ($jsonContent.Bsarch -ne $true -or $jsonContent.BsarchPath -ne $script:bsarch) {
        $jsonContent.Bsarch = $true
        $jsonContent.BsarchPath = $script:bsarch
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content $script:jsonFilePath
        Write-output "ToastPRP.json has been updated with the bsarch path."
    }
}
function Invoke-Archiver {
    param (
        [bool]$CheckBa2Path = $false,
        [string]$CallingFunction
    )

    $script:ba2 = Join-Path $script:data "$script:EXT - Main.ba2"

    try {
        # Check if BA2 path is valid
        if ($CheckBa2Path -and (!(Test-Path $script:ba2))) {
            Write-Error "The BA2 path is invalid or does not exist: $script:ba2"
            return
        }

        # Check if working directory is null
        if ($null -eq $script:workingdir) {
            Write-Error "The working directory path is null. Please ensure it is properly defined."
            return
        }

        # Ensure working directory exists
        if (!(Test-Path $script:workingdir)) {
            New-Item -ItemType Directory -Path $script:workingdir -Force | Out-Null
        }

        # Ensure Meshes subdirectory exists
        $meshesSubdir = Join-Path $script:workingdir "Meshes"
        if (!(Test-Path $meshesSubdir)) {
            New-Item -ItemType Directory -Path $meshesSubdir | Out-Null
        }

        # Handle different calling functions
        switch ($CallingFunction) {
            "PackMesh" {
                if (Test-Path $script:Meshesdir) {
                    Get-ChildItem -Path $script:Meshesdir -ErrorAction SilentlyContinue | Move-Item -Destination $meshesSubdir -Force -ErrorAction SilentlyContinue
                }
                else {
                    Write-Warning "The source directory '$script:Meshesdir' does not exist."
                }
            }
            "PackMeshVis" {
                if (Test-Path $script:Meshesdir) {
                    Get-ChildItem -Path $script:Meshesdir -ErrorAction SilentlyContinue | Copy-Item -Destination $meshesSubdir -Recurse -Force -ErrorAction SilentlyContinue
                }
                else {
                    Write-Warning "The source directory '$script:Meshesdir' does not exist."
                }

                $visSubdir = Join-Path $script:workingdir "vis"
                if (!(Test-Path $visSubdir)) {
                    New-Item -ItemType Directory -Path $visSubdir | Out-Null
                }
                if (Test-Path $script:PrevisDIR) {
                    Get-ChildItem -Path $script:PrevisDIR -ErrorAction SilentlyContinue | Copy-Item -Destination $visSubdir -Recurse -Force -ErrorAction SilentlyContinue
                }
                else {
                    Write-Warning "The source directory '$script:PrevisDIR' does not exist."
                }
            }
        }

        # Define the log file paths for this attempt
        $unpackLogPath = Join-Path $script:logPath "Unpack.log"
        $packLogPath = Join-Path $script:logPath "Pack1.log"
        if (Test-Path $packLogPath) {
            $packLogPath = Join-Path $script:logPath "Pack2.log"
        }

        # Unpacking operation
        if ($CheckBa2Path) {
            Write-Debug "Unpacking archive: $script:ba2 to $script:workingdir"
            $unpackOutput = & $script:bsarch "unpack" "$script:ba2" "$script:workingdir" "-mt" 2>&1
            $unpackOutput | Tee-Object -FilePath $unpackLogPath
            Write-Output "Unpacking log saved to $unpackLogPath"
            #Add-Content -Path $mainLogPath -Value (Get-Content $unpackLogPath)
            Remove-Item $unpackLogPath
        }

        # Packing operation
        Write-Debug "Packing directory: $script:workingdir into archive: $script:ba2"
        $packOutput = & $script:bsarch "pack" "$script:workingdir" "$script:ba2" "-fo4" "-z" "-mt" "-share" 2>&1
        $packOutput | Tee-Object -FilePath $packLogPath
        Write-Output "Packing log saved to $packLogPath"
        #Add-Content -Path $mainLogPath -Value (Get-Content $packLogPath)
        Remove-Item $packLogPath

    }
    catch {
        Write-Error "An error occurred during archiving: $_"
        Write-output "Error Details: $_"
        return
    }

    # Clean up working directory if needed
    if ($CheckBa2Path) {
        Remove-Item -Path $script:workingdir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
#PEBKAC
function MoveScriptToCorrectDirectory {
    if ([string]::IsNullOrWhiteSpace($script:fo4)) {
        Write-output "The 'installed path' is empty or null."
        return
    }

    $script:scriptPath = Join-Path $script:fo4 (Split-Path $PSCommandPath -Leaf)
    if ($PSCommandPath -eq $scriptPath) {
        Write-Host "Script directory vindicated" -ForegroundColor Green
        return
    }

    $filesToMove = @(
        @{
            Source      = $PSCommandPath
            Destination = $scriptPath
            Name        = "Script"
        },
        @{
            Source      = $script:jsonFilePath
            Destination = $jsonFileDestinationPath
            Name        = $script:jsonFileName
        }
    )

    foreach ($file in $filesToMove) {
        try {
            if (!(Test-Path -Path $file.Source)) {
                Write-output "Source file $file.Source does not exist."
                continue
            }
            if (!(Test-Path -Path $file.Destination)) {
                Write-output "Destination directory $file.Destination does not exist."
                continue
            }
            Copy-Item -Path $file.Source -Destination $file.Destination -ErrorAction Stop
            Write-output "$($file.Name) has been copied to the correct directory: $($file.Destination)"
            Remove-Item -Path $file.Source -Force -ErrorAction Stop
            Write-output "Old $($file.Name) has been deleted."
        }
        catch {
            Write-output "Failed to copy or delete $($file.Name): $_"
            return
        }
    }
}



#Beginning of execution 
#==================================================================================================================================================================================================================================================================================================== # 

function Precombines {
    Write-Output "Generating Precombines..."
    ManageJson -CalledByPrecombines
    Invoke-CK -Argument "Precombines"
    $script:done.Invoke() 
    Wait-ForFile -FileName $script:CombinedESP -Caller "Precombines"
    Remove-Item "$script:CombinedESP"
    $script:done.Invoke() 
}

function PSGCompression {
    Invoke-CK -Argument "PSGCompression"
    Wait-ForFile -FileName $script:CSG -Caller 'PSGCompression'
    if (Test-Path "$EXT - Geometry.csg") {
        Remove-Item "$EXT - Geometry.psg" -Force
    }
}

function PackMesh {
    Write-Output "Making Archive of Files to accelerate generation..."
    Invoke-Archiver -ErrorAction Stop -CallingFunction "PackMesh"
    $script:done.Invoke() 
}

function GenerateCDX { 
    Invoke-CK -Argument "GenerateCDX"
    $script:done.Invoke() 
}

function Previs {
    Invoke-CK -Argument "Previs"
    Wait-ForFile $script:previsESP
    Invoke-xEdit # Moved before removing previsESP
    Wait-ForFile -FileName $script:previsESP -Caller "Previs"
    Remove-Item $script:previsESP
    $script:done.Invoke() 
}

function PackMeshVis {
    Rename-Texture -ba2
    Write-Output "Making Archive of Files to finalize structure..."
    if ($null -ne $script:workingdir -and $null -ne $script:ba2) {
        Invoke-Archiver -CheckBa2Path $true -CallingFunction "PackMeshVis"
    }
    else {
        Write-Error "Required paths are null. Cannot proceed with archiving."
    }
    $script:done.Invoke() 
}

function CreateZip {
    $script:zipFilePath = Join-Path $script:data "ToastPRP\GeneratedFiles\$EXT.zip"
    $script:filesToCompress = @(
        (Join-Path $script:data $ESP),
        (Join-Path $script:data "$EXT - Main.ba2"),
        (Join-Path $script:data "$EXT - Geometry.csg"),
        (Join-Path $script:data "$EXT.cdx")
    )
    
    # Ensure the directory for the zip file exists
    $zipDirectory = [System.IO.Path]::GetDirectoryName($script:zipFilePath)
    if (!(Test-Path $zipDirectory)) {
        New-Item -ItemType Directory -Path $zipDirectory -Force | Out-Null
    }
    
    # Create a new zip file
    Compress-Archive -Path $script:filesToCompress -DestinationPath $script:zipFilePath -Force
    
    Write-Output "File saved to $zipFilePath"
    Remove-Item -Path $script:filesToCompress
    Write-Output "Zipped files deleted"
}

$jsonContent = ManageJson

$functions = @(
    "Precombines",
    "PSGCompression",
    "PackMesh",
    "GenerateCDX",
    "Previs",
    "PackMeshVis"
)

function Execute {
    param (
        [int]$startFunction = 0
    )

    try {
        $jsonContent = Get-Content -Path $script:jsonFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Error reading JSON file: $_"
        return
    }

    if ($script:ESP -notin $jsonContent.'ESP-WIP') {
        $startFunction = 0
    }
    else {
        $promptString = "Enter the number of the function you want to start from (0-$($functions.Count - 1)):`n"
        $promptString += ($functions | ForEach-Object { "$($_.Index). $_" }) -join "`n"

        do {
            $startFunctionInput = Read-Host -Prompt $promptString
            if ($startFunctionInput -match '^\d+$') {
                $startFunction = [int]::Parse($startFunctionInput)
            }
            else {
                Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
            }
        } while ($startFunction -lt 0 -or $startFunction -ge $functions.Count -or !($startFunctionInput -match '^\d+$'))
    }

    foreach ($functionName in $functions[$startFunction..($functions.Count - 1)]) {
        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
            Write-Verbose "Executing function: $functionName"
            if ($functionName -eq "PackMeshVis") {
                if ($null -eq $script:EXT) {
                    Write-Error "EXT variable is not set. Cannot proceed with archiving."
                    continue
                }
            }
            & $functionName
        }
        else {
            Write-Warning "Function '$functionName' does not exist."
        }
    }
}


if (!($Debug)) {
    $introText = @"
HUGE thanks to Soul on discord for helping me make sense of powershell!

THIS SCRIPT IS ASSUMING THAT... 
You're using Mod Organizer 2 & this script is in the Fallout 4 install directory and...

THE PJM SCRIPT HAS BEEN RAN AND THE RESULTING ESP FILE IS WHATS BEING MODIFIED

Please reference the links to all needed resources here:
https://diskmaster.github.io/ModernPrecombines/MANUAL
https://www.nexusmods.com/fallout4/mods/69978
https://www.nexusmods.com/fallout4/mods/51165
____________________________________________________________________________________________________
"@
    Write-output $introText
    $text = "Welcome to CannibalToast's Previsbines Automation Script; Stay Toasty!`n`n"
    for ($i = 0; $i -lt $text.Length; $i++) {
        $char = $text[$i]
        Write-Host -NoNewline $char -ForegroundColor Blue
        Start-Sleep -Milliseconds 10
    }
}

try {
    MoveScriptToCorrectDirectory
    DLBSArch
    QueryESP
    Backup-ESP
    Execute
    CreateZip
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    Write-output "Previsbines automation completed."
        Stop-Transcript
    
}
