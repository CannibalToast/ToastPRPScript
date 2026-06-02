param(
    [switch]$Debug,
    [string]$OneOff = $null,
    [switch]$iknowwhatimdoing,
    [switch]$toast
)

Write-Information "Running ToastPRP.ps1"
Add-Type -AssemblyName System.Windows.Forms

# If you have multiple installs of fallout 4 on one machine (You masochist....) make a copy of this script and change the $fo4 variable to the path of the second install and delete the regkey variable. 
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
$script:done = "$([char]27)[32mDone!$([char]27)[0m"
$script:PJMLog = "Toast-PJM-{0:MM-dd-yyyy-HH-mm}.log" -f (Get-Date)
# Texture/voice BA2 archives live in the Data folder root (not subfolders).
$script:TextureArchiveNamePattern = '^(DLC.* - Textures.*|cc.* - Textures.*|Fallout4 - Textures.*|(Fallout4|DLC.*|cc.*) - Voices.*)$'
$script:executionSucceeded = $true
#PEBKAC
switch ($true) {
    ($toast -eq $true) {
        Write-Host "Toast mode enabled. Skipping confirmations and warnings." -ForegroundColor Blue
        $iknowwhatimdoing = $true
        $debug = $true
        break
    }
    ($iknowwhatimdoing -eq $false) {
        if ((Get-ChildItem -Path (Join-Path $script:Meshesdir "Precombined") -ErrorAction SilentlyContinue) -or (Get-ChildItem -Path $script:workingdir -ErrorAction SilentlyContinue)) {
            Write-Host "[UNKNOWN PRECOMBINED FILES DETECTED]" -ForegroundColor Red
            Write-Output "This may be due to currently loaded mods which have unpacked precombines, or leftover files from previous script failure(s)."
            Write-Host "THIS WILL MOST LIKELY CAUSE ISSUES DOWN THE LINE, HEED THIS WARNING!!!!" -ForegroundColor Red
            $script:yn = Read-Host "Do you wish to continue(Y) or close the script(N)?"
            If ($yn -eq "n") {
                Write-Host "Please find the origin of these files and either pack them into an archive or remove them to prevent any issues during generation." -ForegroundColor Red
                if ($host.Name -eq "ConsoleHost") {
                    Stop-Transcript
                    exit
                }
                else {
                    exit
                }
            }
        }
    }
    ($iknowwhatimdoing -eq $true) {
        $confirmation = Read-Host "Please type 'I know what I'm doing' to continue, caps don't matter"
        if ($confirmation -eq "I know what I'm doing" -or $confirmation -eq "i know what i'm doing") {
            Write-Host "Confirmation received. Continuing..."
            $iknowwhatimdoing = $true
            $debug = $true
            Write-Host "iknowwhatimdoing mode enabled" -ForegroundColor Yellow
            Set-PSReadLineOption -ContinuationPrompt "=> "
        }
        else {
            Write-Host "Incorrect confirmation. Exiting script."
            exit
        }
        break
    }
}

# Check for debug mode after the switch
if ($iknowwhatimdoing -or $Debug -or $toast) {
    Write-Host "Debug mode enabled, all debug output will be displayed in the color Yellow" -ForegroundColor Yellow
}

function Log2Transcript {
    param(
        [string]$sourceFilePath
    )
    
    # Get the full path of the source file
    $fullSourcePath = Join-Path $PWD $sourceFilePath
    
    # Check if the source file exists
    if (-not (Test-Path $fullSourcePath)) {
        Write-Error "Source file not found: $fullSourcePath"
        return
    }
    
    # Read the specified file
    $fileContent = Get-Content -Path $fullSourcePath -Raw
    
    # Set InformationPreference to Continue to ensure Write-Information works
    $oldInfoPref = $InformationPreference
    $InformationPreference = 'Continue'
    
    try {
        # Write the log entry using Write-Information and redirect output
        & { Write-Information "$(Get-Date): $fileContent" } 6>&1 > $null -Wait
        Write-Host "Log entry added to transcript." -ForegroundColor Green
    } catch {
        Write-Error "Failed to write to transcript: $_"
    } finally {
        # Restore the original InformationPreference
        $InformationPreference = $oldInfoPref
    }
}


function Write-CustomDebug {
    param (
        [object]$Message
    )

    if ($iknowwhatimdoing -eq $true) {
        if ($Message -is [hashtable]) {
            $tableData = @()
            foreach ($key in $Message.Keys) {
                $tableData += [PSCustomObject]@{
                    Key   = $key
                    Value = $Message[$key]
                }
            }
            $tableData | Format-Table -AutoSize
        }
        else {
            Write-Output "$([char]27)[33m$Message$([char]27)[0m"
        }
    }
}

function Get-TextureArchiveFiles {
    param(
        [string]$Extension
    )

    Get-ChildItem -Path $script:data -Filter "*$Extension" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $script:TextureArchiveNamePattern }
}

function Rename-Texture {
    param (
        [switch]$BA2, # Parameter to indicate conversion to .ba2
        [switch]$BA22, # Parameter to indicate conversion to .ba22
        [switch]$SkipRename,
        [switch]$Wait    # Parameter to indicate if the function should wait for renaming to complete
    )

    if ($SkipRename) {
        Write-Output "Skipping file renaming due to SkipRename flag."
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

    $sourceFiles = @(Get-TextureArchiveFiles -Extension $sourceFileType)

    if (!($sourceFiles)) {
        Write-Output "No $sourceFileType files found. Skipping renaming."
        return
    }

    # Collect file information for the table
    $fileTable = @()

    try {
        Write-Output "Converting files to $targetFileType..."
        $sourceFiles | ForEach-Object {
            $newName = $_.BaseName + $targetFileType
            Rename-Item -Path $_.FullName -NewName $newName
            
            # Add file information to the table
            
            if ($Debug -or $iknowwhatimdoing) {
                $fileTable += [PSCustomObject]@{
                    OriginalName = $_.Name
                    NewName      = $newName
                    
                }
            }
        }
        Write-Output "Renamed BA2 files"

        # Display the table
        $fileTable | Format-Table -AutoSize

        if ($Wait) {
            Write-Output "Waiting for renaming operations to complete..."
            # Wait for all renaming operations to complete
            while ($true) {
                $remainingFiles = @(Get-TextureArchiveFiles -Extension $sourceFileType)
                if (-not $remainingFiles.Count) {
                    break
                }
                Start-Sleep 1
            }
            Write-Output "All renaming operations completed."
        }
    }
    catch {
        Write-Error "An error occurred while converting files: $_"
        Write-Output "Please ensure that you have the necessary permissions to rename files and that the files are not in use by another process."
        Write-Output "Aborting script execution."
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
    $expectedScriptPath = Join-Path $script:fo4 (Split-Path $PSCommandPath -Leaf)
    if ((Test-Path $script:bsarch) -and ($PSCommandPath -eq $expectedScriptPath)) {
        Write-Host "All Systems Green" -ForegroundColor Green
    }
    else {
        throw "Script setup failed. Place ToastPRP.ps1 in the Fallout 4 install directory and ensure bsarch.exe is present or can be downloaded."
    }

    $useOwnEsp = Read-Host "Are you using your own .esp file? (IF NOT PRESS `N` TO PATCH ALL LOADED PLUGINS) (y/n)"
    switch ($useOwnEsp.ToLower()) {
        "y" {
            $prompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                InitialDirectory = $script:data
                Filter           = "Elder Scrolls Plugin (*.esp)|*.esp"
            }
            if ($prompt.ShowDialog() -eq 'OK') {
                $script:ESP = [System.IO.Path]::GetFileName($prompt.FileName)
                if (![string]::IsNullOrEmpty($script:ESP)) {
                    Write-Output "Using ESP: $script:ESP"
                }
            }
            else {
                Write-Error "No ESP file selected. Exiting script."
                exit
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
                    Write-Output "Patching all loaded plugins"
                    $seedName = Read-Host "Enter a name for your output ESP (without .esp extension)"
                    $script:mod = ""
                    $script:ESP = "ToastPRP-$seedName.esp"  # This will be used later in the script
                    $script:pas = "FO4Check_PreVisbines.pas"
                    Invoke-xEdit -caller 'QueryESP' -mod "" -seed:`"$seedName`"  # Pass the seedName to Invoke-xEdit
                }
                "2" {
                    Write-Output "What ESP file would you like to patch?"
                    $prompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                        InitialDirectory = $script:data
                        Filter           = "Elder Scrolls Plugin (*.esp; *.esl; *.esm)|*.esp; *.esl; *.esm"
                    }
                    if ($prompt.ShowDialog() -eq 'OK') {
                        $script:mod = [System.IO.Path]::GetFileName($prompt.FileName)
                        $script:ESP = "ToastPRP-" + [System.IO.Path]::GetFileNameWithoutExtension($script:mod) + ".esp"
                        $script:pas = "FO4Check_PreVisbines.pas"
                        Write-Output "Patching ESP: $script:mod"
                        Write-CustomDebug "Calling Invoke-xEdit with caller='QueryESP' and mod='$script:mod'"
                        Invoke-xEdit -caller 'QueryESP' -mod $script:mod
                    }
                    else {
                        Write-Error "No ESP file selected. Exiting script."
                        exit
                    }
                }
                "3" {
                    Write-Output "Goodbye!"
                    exit
                }
                default {
                    Write-Error "Invalid option selected. Exiting script."
                    exit
                }
            }
        }
        default {
            Write-Error "Invalid input. Exiting script."
            exit
        }
    }

    # Set common variables after ESP is determined
    $script:EXT = [System.IO.Path]::GetFileNameWithoutExtension($script:ESP)
    $script:PSG = "$script:data\$($script:EXT) - Geometry.psg"
    $script:CSG = "$script:data\$($script:EXT) - Geometry.csg"
    $script:workingdir = Join-Path $script:data "workingdir"
    $script:ba2 = Join-Path $script:data "$script:EXT - Main.ba2"

    if ($debug -or $iknowwhatimdoing) {
        Write-CustomDebug -Message @{
            "Bsarch"            = $script:bsarch
            "PWD"               = $PSCommandPath
            "Fallout 4 Path"    = $script:fo4
            "FO4 Data Path"     = $script:data
            "ESP"               = $script:ESP
            "EXT"               = $script:EXT
            "PSG"               = $script:PSG
            "CSG"               = $script:CSG
            "Working Directory" = $script:workingdir
            "BA2 Path"          = $script:ba2
        }
    }
    # Create a unique folder for this attempt
    $logFolder = Join-Path $script:data "ToastPRP\Logs\"
    if (!(Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
    }
    $script:mainLogPath = "$script:data\ToastPRP\Logs\$script:EXT-{0:MM-dd-yyyy-HH-mm}.log" -f (Get-Date)
    Start-Transcript -Path $script:mainLogPath
    $script:logPath = "$logFolder"
    if (Test-Path *pack*.log) {
        Remove-Item *pack*.log -Force -ErrorAction SilentlyContinue
        Write-Output "Removing undeleted orphan logs in path"
    }
    try {
        Log2Transcript $script:PJMLog
    } catch {
        Write-Error "Error in Log2Transcript: $_"
    }
    Write-Output "ESP setup completed successfully."
}

function Invoke-xEdit {
    param (
        [string]$caller,
        [string]$mod = $null
    )

    # Get ESP path
    $espPath = Join-Path $script:data $script:ESP
    
    # Initialize checksum
    $initialChecksum = $null
    
    switch (Test-Path $espPath) {
        $true {
            $initialChecksum = Get-FileHash -Path $espPath -Algorithm SHA256
            
            if ($debug -or $iknowwhatimdoing) {
                Write-CustomDebug -Message @{
                    "Caller:"          = $caller
                    "Mod:"             = $mod
                    "xEdit:"           = $xEdit
                    "Script:"          = $script
                    "Initial Checksum" = $initialChecksum.Hash
                }
            }
        }
        $false {
            if ($debug -or $iknowwhatimdoing) {
                Write-CustomDebug -Message "New ESP file will be created: $script:ESP"
            }
        }
    }

    # Determine script arguments based on caller
    switch ($caller) {
        'QueryESP' {
            switch ($mod) {
                '' {
                    $scriptArgument = "-script:`"$script:pas`" -Full -nobuildrefs -mod -seed:`"ToastPRP-$seedName.esp`" -log:$script:PJMLog"
                    $KeysToSend = "Enter"
                }
                default {
                    $modWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($mod)
                    $modWithEspExtension = "ToastPRP-$modWithoutExtension.esp"
                    $scriptArgument = "-script:`"$script:pas`" -Full -nobuildrefs -Mod:`"$mod`" -seed:`"$modWithEspExtension`" -log:$script:PJMLog"
                    $KeysToSend = "Enter"
                }
            }
        }
        default {
            $scriptArgument = "-script:`"$script:pas`" -nobuildrefs -Mod:`"$script:ESP`" -log:$script:PJMLog"
            $KeysToSend = "PageDown", "Space", "Enter"
        }
    }

    if ($debug -or $iknowwhatimdoing) { Write-CustomDebug -Message "Argument is $scriptArgument" }
    
    # Start xEdit process
    $xEditProcess = Start-Process -FilePath $xEdit -ArgumentList $scriptArgument -PassThru -NoNewWindow
    Start-Sleep -Seconds 3
    
    # Initialize state variables
    $script:firstFO4ScriptDetected = $false
    $script:seenApplyingScript = $false
    $script:alreadyReportedApplyingScript = $false
    $script:exitLoop = $false
    $currentTitle = ""
    $lastTitle = ""
    $startTime = Get-Date
    $timeout = 900 # 15 minute timeout

    # Send initial keystrokes
    if ($KeysToSend) {
        Keypress -KeysToSend $KeysToSend
    }

    # Window title monitoring loop
    while (-not $script:exitLoop) {
        $titleBuilder = New-Object System.Text.StringBuilder 256
        [WindowHelper]::GetWindowText($xEditProcess.MainWindowHandle, $titleBuilder, $titleBuilder.Capacity) | Out-Null
        $currentTitle = $titleBuilder.ToString()

        # Check for timeout
        switch ((Get-Date) - $startTime) {
            { $_.TotalSeconds -gt $timeout } {
                Write-Error "Operation timed out after $timeout seconds"
                $xEditProcess.CloseMainWindow()
                return $false
            }
        }

        # Title change detection
        switch ($currentTitle -ne $lastTitle) {
            $true {
                if ($debug -or $iknowwhatimdoing) {
                    Write-CustomDebug -Message "Title changed from '$lastTitle' to '$currentTitle'"
                }

                # Process title states
                switch -Regex ($currentTitle) {
                    "FO4Script" {
                        $script:firstFO4ScriptDetected = $true
                        switch ($script:seenApplyingScript) {
                            $true {
                                Write-Output "xEdit script completed, closing..."
                                Start-Sleep -Seconds 2
                                $xEditProcess.CloseMainWindow()
                                $xEditProcess.WaitForExit(5000)
                                $script:exitLoop = $true
                            }
                            $false {
                                if ($debug -or $iknowwhatimdoing) {
                                    Write-CustomDebug -Message "Initial FO4Script state detected"
                                }
                            }
                        }
                    }
                    "Applying script" {
                        switch ($script:alreadyReportedApplyingScript) {
                            $false {
                                Write-Output "Waiting for script completion"
                                $script:seenApplyingScript = $true
                                $script:alreadyReportedApplyingScript = $true
                                Start-Sleep -Milliseconds 500
                            }
                        }
                    }
                    default {
                        if ($debug -or $iknowwhatimdoing) {
                            Write-CustomDebug -Message "Unhandled window title: $currentTitle"
                        }
                    }
                }
                $lastTitle = $currentTitle
            }
        }
        Start-Sleep -Milliseconds 50
    }

    # Verify script execution
    switch ($script:firstFO4ScriptDetected) {
        $false {
            Write-Error "xEdit script did not run successfully"
            return $false
        }
    }

    # Checksum verification
    switch ($initialChecksum) {
        { $null -ne $_ } {
            Start-Sleep -Seconds 2
            $finalChecksum = Get-FileHash -Path $espPath -Algorithm SHA256

            if ($debug -or $iknowwhatimdoing) {
                Write-CustomDebug -Message @{
                    "Initial Checksum" = $initialChecksum.Hash
                    "Final Checksum"   = $finalChecksum.Hash
                }
            }

            switch ($initialChecksum.Hash -eq $finalChecksum.Hash) {
                $true {
                    Write-Error "ESP file was not modified by xEdit script! Checksums match, indicating no changes were made."
                    Write-Error "Initial: $($initialChecksum.Hash)"
                    Write-Error "Final: $($finalChecksum.Hash)"
                    
                    $backupPath = Join-Path "$script:data\ToastPRP\ESP_Backups" $script:ESP
                    switch (Test-Path $backupPath) {
                        $true {
                            Write-Output "Attempting to restore from backup..."
                            try {
                                Copy-Item -Path $backupPath -Destination $espPath -Force
                                Write-Output "Backup restored successfully"
                            }
                            catch {
                                Write-Error "Failed to restore backup: $_"
                            }
                        }
                    }
                    throw "xEdit script failed to modify ESP file. Script execution aborted."
                }
                $false {
                    Write-Output "ESP file was successfully modified (checksums differ)"
                    Log2Transcript $script:PJMLog
                    
                    if ($caller -eq 'Precombines') {
                        Remove-Item $script:CombinedESP
                    }
                    if ($caller -eq 'Previs') {
                        Remove-Item $script:previsESP
                    }
                    return $true
                }
            }
        }
        default {
            switch (Test-Path $espPath) {
                $true {
                    Write-Output "New ESP file was successfully created"
                    Log2Transcript $script:PJMLog
                    return $true
                }
                $false {
                    Write-Error "Failed to create new ESP file"
                    throw "xEdit script failed to create new ESP file. Script execution aborted."
                }
            }
        }
    }
}

function Invoke-CK ([string]$Argument) {
    if ($debug -or $iknowwhatimdoing) {
        # Table of arguments for debugging
        # Create an array of custom objects
        $tableData = @(
            [PSCustomObject]@{ Function = "Precombines"; Argument = "-GeneratePrecombined:`"$ESP`"" }
            [PSCustomObject]@{ Function = "PSGCompression"; Argument = "-CompressPSG:`"$ESP`"" }
            [PSCustomObject]@{ Function = "GenerateCDX"; Argument = "-buildcdx:`"$ESP`"" }
            [PSCustomObject]@{ Function = "Previs"; Argument = "-GeneratePreVisdata:`"$ESP`"" }
        )

        # Display the table using Format-Table
        $tableData | Format-Table -AutoSize

    }
    # Switch statement to handle different arguments
    switch ($Argument) {
        "Precombines" {
            Rename-Texture -ba2
            Write-Output "Generating Precombines..."
            $ckArgument = "-GeneratePrecombined:`"$script:ESP`" clean all"
            $script:pas = "Batch_FO4MergeCombinedObjectsandCheck.pas"
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
            Rename-Texture -BA22
            Write-Output "Generating Previs Data..."
            $ckArgument = "-GeneratePreVisdata:`"$script:ESP`" clean all"
            $script:pas = "Batch_FO4MergePreVisandCleanRefr.pas"
        }
        default {
            Write-Error "Unknown argument: $Argument"
            return
        }
    }
    
    if ($debug -or $iknowwhatimdoing) { Write-CustomDebug -Message "Starting Creation Kit with arguments: $ckArgument" }
    $startTime = Get-Date
    Start-Process -FilePath $script:CK -ArgumentList $ckArgument -Wait
    #Log2Transcript "CKLOG.log"
    
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
        [int]$TimeoutSeconds = 10,
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
            Write-Warning "Timeout reached while waiting for $FileName to appear, aborting."
            exit
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
                
            }
            'CreateZIP' {
                Remove-Item $filesToCompress
            }
            'Previs' {
                Write-output "Calling Invoke-xEdit with caller='Previs' and mod='$SelectedFile'"
                Invoke-xEdit -caller 'Previs'  # Moved before removing CombinedObjects.esp
                
            }
            # Add more cases as needed
            default {
                if ($debug -or $iknowwhatimdoing) { Write-Output "No action taken for caller: $Caller" }
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
    
    $backupFilePath = Join-Path -Path $backupPath -ChildPath $ESP
    
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
        [string]$PredefinedChecksum = "97FB589E0542806F105C28FF005C8DD51EEB118E0A18497247590A3BBA73D865D3956B769E6128ED63A3D5333017949EA26AC6DC87570E05FE50CBB3E7C51CC3"
    )

    function Test-BsarchChecksum {
        if (!(Test-Path $script:bsarch)) { return $false }
        $hash = (Get-FileHash $script:bsarch -Algorithm SHA512).Hash
        return $hash -eq $PredefinedChecksum
    }

    function DownloadAndValidateBsarch {
        Invoke-WebRequest -Uri $BsarchUrl -OutFile $script:bsarch
        if (Test-BsarchChecksum) {
            Write-Output "bsarch.exe downloaded and validated successfully."
            return $true
        }

        Write-Output "Downloaded bsarch.exe failed checksum validation. Either download failed or the executable was updated on the GitHub repo."
        Remove-Item -Path $script:bsarch -ErrorAction SilentlyContinue
        return $false
    }

    if (!(Test-Path $script:bsarch) -or !(Test-BsarchChecksum)) {
        Write-Output "Attempting to download and validate bsarch.exe..."
        if (!(DownloadAndValidateBsarch)) {
            throw "Failed to obtain a valid bsarch.exe. Check your network connection or download it manually."
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

        # Ensure working directory exists
        if (!(Test-Path $script:workingdir)) {
            New-Item -ItemType Directory -Path $script:workingdir -Force | Out-Null
        }
        $script:visSubdir = Join-Path $script:workingdir "vis"
        $script:MeshesSubdir = Join-Path $script:workingdir "Meshes"
        # Handle different calling functions
        if ($CallingFunction -in @('PackMesh', 'PackMeshVis')) {
            if (Test-Path $script:Meshesdir) {
                Move-Item -Path $script:Meshesdir -Destination $script:workingdir -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-Warning "The source directory '$script:Meshesdir' does not exist."
            }
        }
        if ($CallingFunction -eq 'PackMeshVis') {
            if (Test-Path $script:PrevisDIR) {
                Move-Item -Path $script:PrevisDIR -Destination $script:workingdir -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-Warning "The source directory '$script:PrevisDIR' does not exist."
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
            Write-CustomDebug -Message "Unpacking archive: $script:ba2 to $script:workingdir"
            $unpackOutput = & $script:bsarch "unpack" "$script:ba2" "$script:workingdir" "-mt" 2>&1
            $unpackOutput | Tee-Object -FilePath $unpackLogPath
            Write-Output "Unpacking log saved to $unpackLogPath"
            #Add-Content -Path $mainLogPath -Value (Get-Content $unpackLogPath)
            Remove-Item $unpackLogPath
        }
        $hasMeshContent = (Test-Path $script:MeshesSubdir) -and
            (Get-ChildItem -Path $script:MeshesSubdir -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hasMeshContent) {
            # Packing operation
            Write-CustomDebug -Message "Packing directory: $script:workingdir into archive: $script:ba2"
            $packOutput = & $script:bsarch "pack" "$script:workingdir" "$script:ba2" "-fo4" "-z" "-mt" "-share" 2>&1
            $packOutput | Tee-Object -FilePath $packLogPath
            Write-Output "Packing log saved to $packLogPath"
            #Add-Content -Path $mainLogPath -Value (Get-Content $packLogPath)
            Remove-Item $packLogPath
        }
        else {
            Write-Error "The source directory '$script:workingdir' is empty. No packing operation performed."
        }

        # Clean up working directory if needed
        if ($CheckBa2Path) {
            Remove-Item -Path $script:workingdir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } 
    catch {
        Write-Error "An error occurred during unpacking: $_"
        Write-Output "Error Details: $_"
        throw  # Re-throw the error to be caught by the calling function if needed
    }
}
#PEBKAC
function MoveScriptToCorrectDirectory {
    if ([string]::IsNullOrWhiteSpace($script:fo4)) {
        Write-output "The 'installed path' is empty or null."
        return
    }

    $script:scriptPath = Join-Path $script:fo4 (Split-Path $PSCommandPath -Leaf)
    if ($PSCommandPath -eq $script:scriptPath) {
        Write-Host "Script directory vindicated" -ForegroundColor Green
        return
    }

    $jsonDestination = Join-Path $script:fo4 $script:jsonFileName
    $filesToMove = @(
        @{
            Source      = $PSCommandPath
            Destination = $script:scriptPath
            Name        = "Script"
        },
        @{
            Source      = $script:jsonFilePath
            Destination = $jsonDestination
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
    ManageJson -CalledByPrecombines
    Invoke-CK -Argument "Precombines"
    Wait-ForFile -FileName $script:CombinedESP -Caller "Precombines"
    $done 
    $script:precombinesran = $true
}

function PSGCompression {
    if ($script:precombinesran -eq $true) {
        Invoke-CK -Argument "PSGCompression"
        Wait-ForFile -FileName $script:CSG -Caller 'PSGCompression'
        if (Test-Path $script:CSG) {
            Remove-Item $script:PSG -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Error "Precombines has not been ran. Cannot run PSGCompression."
        exit
    }
}

function PackMesh {
    Write-Output "Making Archive of Files to accelerate generation..."
    try {
        Invoke-Archiver -CallingFunction "PackMesh"
        $done 
    }
    catch {
        Write-Error "PackMesh failed: $_"
    }
}

function GenerateCDX { 
    Invoke-CK -Argument "GenerateCDX"
    $done 
}

function Previs {
    Invoke-CK -Argument "Previs"
    Wait-ForFile -FileName $script:PrevisESP -Caller "Previs"
    $done
    $script:previsran = $true
}

function PackMeshVis {
    Write-Output "Making Archive of Files to finalize structure..."
    if ($null -ne $script:workingdir -and $null -ne $script:ba2) {
        Invoke-Archiver -CheckBa2Path $true -CallingFunction "PackMeshVis"
    }
    else {
        Write-Error "Required paths are null. Cannot proceed with archiving, closing script."
        exit
    }
    $done
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

$jsonContent = ManageJson | Out-Null

$functions = @(
    "Precombines",
    "PSGCompression",
    "PackMesh",
    "GenerateCDX",
    "Previs",
    "PackMeshVis",
    "CreateZip"
)

function OneOffExecution {
    param (
        [string]$OneOff
    )

    if ($functions -contains $OneOff) {
        Write-Verbose "Executing one-off function: $OneOff"
        & $OneOff
    }
    else {
        Write-Error "Function '$OneOff' does not exist."
    }
}

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
        $menuLines = for ($i = 0; $i -lt $functions.Count; $i++) { "$i. $($functions[$i])" }
        $promptString = "Enter the number of the function you want to start from (0-$($functions.Count - 1)):`n"
        $promptString += ($menuLines -join "`n")

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

    if ($OneOff) {
        OneOffExecution -OneOff $OneOff
    }
    else {
        Backup-ESP
        Execute
        Rename-Texture -BA2
    }
}
catch {
    $script:executionSucceeded = $false
    Write-Error "An error occurred: $_"
}
finally {
    if ($script:executionSucceeded) {
        Write-Output "Previsbines automation completed successfully."
        Write-Host "Thank you for using Cannibal Toasts' Previsbine Generation Script. Stay Toasty!!" -ForegroundColor Green
    }
    else {
        Write-Host "Previsbines automation ended with errors. Review the transcript log for details." -ForegroundColor Red
    }
    Stop-Transcript -ErrorAction SilentlyContinue
}
