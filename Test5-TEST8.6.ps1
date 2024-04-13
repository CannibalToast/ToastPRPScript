$script:transcriptActive = $false
$script:regkey = 'HKLM:\Software\Wow6432Node\Bethesda Softworks\Fallout4'
$script:fo4 = Get-ItemPropertyValue -Path $script:regkey -Name 'installed path' -ErrorAction Stop
$script:data = Join-Path $script:fo4 "data"
$script:CK = "ckpe_loader.exe", "f4ck_loader.exe", "creationkit.exe" | Where-Object { Test-Path $_ } | Select-Object -First 1
$script:Archive2 = Join-Path $script:data "tools/archive2/archive2.exe"
$script:previsESP = Join-Path $script:data "Previs.esp"
$script:PrevisDIR = Join-Path $script:data "vis"
$script:combinedObjectsESP = Join-Path $script:data "CombinedObjects.esp"
$script:workingdir = Join-Path $script:data "workingdir"
$script:Meshesdir = Join-Path $script:data "Meshes"
$script:jsonFileName = "ToastPRP.json"
$script:jsonFilePath = Join-Path -Path $script:fo4 -ChildPath $script:jsonFileName
$script:bsarch = Join-Path $script:fo4 "bsarch.exe"
$script:ba22Files = Get-ChildItem -Path $script:data -Filter "*.ba22" -Recurse -File


Set-PSDebug -Strict -Trace 0 # Change to 1 for debugging
Add-Type -AssemblyName System.Windows.Forms
function Rename-Texture {
    Get-ChildItem -Path "$script:data" -Filter "* - Textures*.ba2*" -Recurse -File |
    Where-Object { $_.Name -match "- Textures\d+\.(ba2|ba22)$" } |
    ForEach-Object {
        $newExt = if ($_.Extension -eq '.ba2') { '.ba22' } else { '.ba2' }
        $newName = $_.BaseName + $newExt
        Rename-Item -Path $_.FullName -NewName $newName
    }
}

if (-not ('WindowHelper' -as [Type])) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Text;
    public class WindowHelper {
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
"@
}

function QueryESP {
    # Ask if the user is using their own .esp file
    $useOwnEsp = Read-Host "Are you using your own .esp file? (IF NOT PRESS `N` TO PATCH ALL LOADED PLUGINS) (y/n)"
    if ($useOwnEsp -eq "y") {
        # Use OpenFileDialog to let the user choose their .esp file
        $prompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            InitialDirectory = $script:data
            Filter           = "Elder Scrolls Plugin (*.esp)|*.esp"
        }
        if ($prompt.ShowDialog() -eq 'OK') {
            $selectedFile = $prompt.FileName
            if (![string]::IsNullOrEmpty($selectedFile)) {
                $fileInfo = Get-Item -Path $selectedFile
                $script:ESP = $fileInfo.Name
                Write-Output "Performing backup for: $ESP"
            }
        }
    } else {
        # Open xEdit using Start-Process with specified arguments
        $script:pas = "FO4Check_PreVisbines.pas"
        Invoke-xEdit -caller 'QueryESP' -Wait
        # Rename xPrevisPatch.esp to the specified name
        $script:ESP = Read-Host "Please enter the new name for xPrevisPatch.esp"
        # Ensure the file has the .esp extension
        if (!($script:ESP.EndsWith(".esp"))) {
            $script:ESP += ".esp"
        }
        # Set the path for the xPrevisPatch.esp file
        $script:previsPatchESP = Join-Path $script:data "xPrevisPatch.esp"
        Rename-Item $script:previsPatchESP -NewName $script:ESP
    }
    $script:EXT = [System.IO.Path]::GetFileNameWithoutExtension($ESP)
    $script:ba2 = Join-Path $script:data "$EXT - Main.ba2"
}

function Invoke-CK ([string]$Argument) {
        if ($ba22Files) {
        Rename-Texture
    }
    $startTime = Get-Date
    Start-Process -FilePath $script:CK -ArgumentList $Argument -Wait
    Write-Output "Completed in $(New-TimeSpan -Start $startTime -End (Get-Date))."
}
function Invoke-xEdit {
    param(
        [string]$caller
    )

    $scriptArgument = "-script:$script:pas -Full -nobuildrefs"
    $KeysToSend = $null

    if ($caller -eq 'QueryESP') {
        # For 'QueryESP', no additional argument and send "Enter"
        Start-Sleep 5
        $KeysToSend = "Enter"
    } else {
        # For other callers, add '-Mod:$ESP' and send "PageDown", "Space", "Enter"
        $scriptArgument += " -Mod:$ESP"
        Start-Sleep 5
        $KeysToSend = "PageDown", "Space", "Enter"
    }

    $xEditProcess = Start-Process -FilePath $xEdit -ArgumentList $scriptArgument -PassThru
    Start-Sleep -Seconds 5
    if ($KeysToSend) {
        Keypress -KeysToSend $KeysToSend
    }
    Start-Sleep -Seconds 15
    while ($true) {
        $title = New-Object System.Text.StringBuilder 256
        [WindowHelper]::GetWindowText($xEditProcess.MainWindowHandle, $title, $title.Capacity) | Out-Null
        $title = $title.ToString()

        if ($title -match "FO4Script") {
            Write-Output "Title change detected (indicates script is complete) Closing..."
            $xEditProcess.CloseMainWindow()
            $xEditProcess.WaitForExit()
            break
        }

        Start-Sleep -Milliseconds 1000
    }
}

function Keypress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet("PageDown", "Space", "Enter", "AltF4")]
        [String[]]$KeysToSend,

        [Parameter(Mandatory=$false, Position=1)]
        [Int]$WaitTimeAfterKeys = 0
    )

    # Wait for 5 seconds
    Start-Sleep -Seconds 5

    # Bring FO4Edit to the foreground (uncomment if needed)
    #$windowHandle = $xEditProcess.MainWindowHandle
    #[WindowHelper]::SetForegroundWindow($windowHandle)

    # Send each key in the array
    foreach ($Key in $KeysToSend) {
        switch ($Key) {
            "PageDown" { [System.Windows.Forms.SendKeys]::SendWait("{PGDN}") }
            "Space"    { [System.Windows.Forms.SendKeys]::SendWait(" ") }
            "Enter"    { [System.Windows.Forms.SendKeys]::SendWait("{ENTER}") }
            "AltF4"    { [System.Windows.Forms.SendKeys]::SendWait("%{F4}") }
        }

        # Wait for 100 milliseconds after each keypress
        Start-Sleep -Milliseconds 100
    }

    # Wait for the specified amount of time after the keys are sent
    Start-Sleep -Milliseconds $WaitTimeAfterKeys
}

function Wait-ForFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [int]$TimeoutSeconds = 60
    )
    
    $filePath = Join-Path -Path $script:data -ChildPath $FileName
    Write-Host "Waiting for $FileName to appear..."
    
    $startTime = Get-Date
    $fileFound = $false
    
    do {
        Start-Sleep -Seconds 1
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
    } while ($true)
    
    if ($fileFound) {
        Write-Host "File found: $filePath"
    }
}

function Backup-ESP { 
    $backupPath = "$script:data\ToastPRP\ESP_Backups"
    Start-Transcript -Path ("$script:data\ToastPRP\Logs\$EXT-{0:MM-dd-yyyy-HH-mm}.log" -f (Get-Date))
    $script:transcriptActive = $true
    # Ensure the backup directory exists
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    
    # Construct the backup file path using only the name of the ESP file
    $backupFilePath = Join-Path -Path $backupPath -ChildPath $ESP
    
    # Copy the ESP file to the backup directory
    $oldFilePath = Join-Path -Path $script:data -ChildPath $ESP
    try {
        Copy-Item -LiteralPath $oldFilePath -Destination $backupFilePath -Force -ErrorAction Stop
        Write-Output "Backup of $ESP created in $backupPath"
    } catch {
        Write-Error "Backup of $ESP failed: $_"
    }
}
function ManageJson {
    param(
        [switch]$CalledByPrecombines
    )
    if (-not (Test-Path $script:jsonFilePath)) {
        $jsonContent = @{
            'ESP-WIP'    = @()
            'xEdit'      = $null
            'Bsarch'     = $false
            'BsarchPath' = $null
        }
    } else {
        $jsonContent = Get-Content $script:jsonFilePath -Raw | ConvertFrom-Json
    }

    if (-not $jsonContent.PSObject.Properties.Name.Contains('xEdit') -or -not $jsonContent.xEdit) {
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Title = "Select FO4Edit file"
        $fileDialog.Filter = "FO4Edit (*.exe)|FO4Edit.exe;FO4Edit64.exe;fo4edit.exe;xEdit.exe;xEdit64.exe"
        if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $selectedFile = $fileDialog.FileName
            if ($selectedFile -match '(?i)(fo4edit|fo4edit64|xedit|xedit64)\.exe$') {
                $jsonContent.'xEdit' = $selectedFile
                $script:xEdit = $selectedFile
            }
        }
    }

    if ($CalledByPrecombines -and $script:ESP -and ($script:ESP -notin $jsonContent.'ESP-WIP')) {
        $jsonContent.'ESP-WIP' += $script:ESP
    }

    $jsonContent.'Bsarch' = $false
    $jsonContent.'BsarchPath' = $null

    $jsonString = $jsonContent | ConvertTo-Json -Depth 100
    Set-Content $script:jsonFilePath -Value $jsonString

    $script:xEdit = $jsonContent.xEdit
    $script:BSArchive = $jsonContent.BsarchPath

    return $jsonContent
}

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
            return $true
        } else {
            Write-Host "Downloaded bsarch.exe failed checksum validation."
            Remove-Item -Path $script:bsarch -ErrorAction SilentlyContinue
            return $false
        }
        Write-Host "bsarch.exe downloaded and validated successfully."
    }

    # Check if bsarch.exe exists and validate checksum, download if necessary
    if (-not (Test-Path $script:bsarch) -or -not (DownloadAndValidateBsarch)) {
        Write-Host "Attempting to download and validate bsarch.exe..."
        if (-not (DownloadAndValidateBsarch)) {
            Write-Host "Failed to obtain a valid bsarch.exe after download attempt. Please check the source or try again later."
            return
        }
    }

    Write-Host "BSArch validated"

    # Update the JSON content with the bsarch path if it has changed
    $jsonContent = ManageJson
    if ($jsonContent.Bsarch -ne $true -or $jsonContent.BsarchPath -ne $script:bsarch) {
        $jsonContent.Bsarch = $true
        $jsonContent.BsarchPath = $script:bsarch
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content $script:jsonFilePath
        Write-Host "ToastPRP.json has been updated with the bsarch path."
    }
}

function Invoke-Archiver ([string[]]$Arguments, [bool]$CheckBa2Path = $false) {
    $startTime = Get-Date
    try {
        if ($CheckBa2Path -and (-not $script:ba2 -or -not (Test-Path $script:ba2))) {
            Write-Error "The BA2 path is invalid or does not exist: $script:ba2"
            return
        }
        
        New-Item -ItemType Directory -Path $script:workingdir -Force | Out-Null

        $archiveExe = if ($jsonContent.Bsarch) { $script:bsarch } else { $script:Archive2 }
        $process = Start-Process $archiveExe -ArgumentList $Arguments -PassThru -NoNewWindow
        $process.WaitForExit()
    } catch {
        Write-Error "An error occurred during archiving: $_"
        return
    }
    
    if ($CheckBa2Path -and !(Test-Path $script:ba2)) {
        Write-Warning "Archive file not found: $script:ba2"
        Write-Host "Full path checked: $(Resolve-Path $script:ba2)"
        exit
    }
    
    $timeTaken = New-TimeSpan -Start $startTime -End (Get-Date)
    Write-Output "Completed in $timeTaken."
}

function MoveScriptToCorrectDirectory {
    if ([string]::IsNullOrWhiteSpace($script:fo4)) {
        Write-Host "The 'installed path' is empty or null."
        return
    }
  
    $scriptPath = Join-Path $script:fo4 (Split-Path $PSCommandPath -Leaf)
    if ($PSCommandPath -eq $scriptPath) {
        Write-Host "Script directory vindicated"
        return
    }

    $filesToMove = @(
        @{
            Source = $PSCommandPath
            Destination = $scriptPath
            Name = "Script"
        },
        @{
            Source = $script:jsonFilePath
            Destination = $jsonFileDestinationPath
            Name = $script:jsonFileName
        }
    )

    foreach ($file in $filesToMove) {
        try {
            Copy-Item -Path $file.Source -Destination $file.Destination -ErrorAction Stop
            Write-Host "$($file.Name) has been copied to the correct directory: $($file.Destination)"
            Remove-Item -Path $file.Source -Force -ErrorAction Stop
            Write-Host "Old $($file.Name) has been deleted."
        } catch {
            Write-Host "Failed to copy or delete $($file.Name): $_"
            return
        }
    }
}


#Beginning of execution 
#==================================================================================================================================================================================================================================================================================================== # 

function Precombines {
    $script:pas = "Batch_FO4MergeCombinedObjectsAndCheck.pas"
    ManageJson -CalledByPrecombines
    Write-Output "Generating Precombines..."
    Invoke-CK -Argument "-GeneratePrecombined:`"$ESP`" clean all" -Wait
    Write-Output "Done!"
    Wait-ForFile -FileName "CombinedObjects.esp"
    Invoke-xEdit
    Write-Output "Done!"
}

function PSGCompression {
    Write-Output "Compressing PSG..."
    Invoke-CK -Argument "-CompressPSG:$ESP"
    if (!(Test-Path "$script:data\$EXT - Geometry.csg")) {
        Write-Warning "COMPRESSED GEOMETRY NOT FOUND! USING UNCOMPRESSED"
    } else { 
        Remove-Item -Path "$script:data\$EXT - Geometry.psg"
        Write-Output "Done!`n"
    }    
}

function PackMesh {
    Write-Output "Making Archive of Files to accelerate generation..."
    # If Bsarch is true, use bsarch.exe to pack the files. Otherwise, use archive2.exe
    if ($jsonContent.Bsarch -eq $true) {
        Move-Item -Path $script:Meshesdir -Destination $script:workingdir -ErrorAction Stop
        Invoke-Archiver -Argument "pack `"$script:workingdir`" `"$script:ba2`" -fo4 -z -mt" -ErrorAction Stop
        if (!(Test-Path $script:ba2)) {
            Write-Warning "ARCHIVE NOT FOUND!"
            return
    }
} else {
    Invoke-Archiver -Argument "`"$script:Meshesdir`" -c=`"$script:ba2`"" -ErrorAction Stop
}
        $directoryToRemove = if ($jsonContent.Bsarch) { $script:workingdir } else { $script:Meshesdir }
        Remove-Item -Path $directoryToRemove -Recurse -Force -ErrorAction Stop
        Write-Output "Done!"
}

function GenerateCDX { 
    Write-Output "Generating Cell Index (CDX)..."
    Invoke-CK -Argument "-buildcdx:$ESP clean all" -Wait
    Write-Output "Done!"
}

function Previs {
    Rename-Texture
    $script:pas = "Batch_FO4MergePreVisandCleanRefr.pas"
    Write-Output "Generating Previs Data..."
    Invoke-CK -Argument "-GeneratePreVisdata:$ESP clean all" -Wait
    Rename-Texture
    Wait-ForFile -FileName "Previs.esp"
    Invoke-xEdit 
    Remove-Item -Path $script:previsESP
    Remove-Item -Path $script:combinedObjectsESP
}

function PackMeshVis {
    Write-Output "Making Archive of Files to finalize structure..."
    # If Bsarch is true, use bsarch.exe to pack the files. Otherwise, use archive2.exe
    if ($jsonContent.Bsarch -eq $true) {
        Move-Item -Path $script:PrevisDIR -Destination $script:workingdir -Force
        Move-Item -Path $script:Meshesdir -Destination $script:workingdir -Force -ErrorAction SilentlyContinue
        Invoke-Archiver -Argument "unpack `"$script:ba2`" `"$script:workingdir`" -mt"
        if (Test-Path $script:ba2) {
            Remove-Item -Path $script:ba2 -Force   
        } else {
            Write-Warning "File not found: $script:ba2"
        }
        Invoke-Archiver -Argument "pack `"$script:workingdir`" `"$script:ba2`" -fo4 -z -mt -share"
        if (!(Test-Path $script:ba2)) {
            Write-Warning "ARCHIVE NOT FOUND!"
            return
        } else {
        $directoryToRemove = if ($jsonContent.Bsarch) { $script:workingdir} else { $script:Meshesdir, $script:PrevisDIR }
        Remove-Item -Path $directoryToRemove -Recurse -Force -ErrorAction Stop
        }
    } else {
        Invoke-Archiver -Argument "`"$script:Meshesdir`",`"$script:PrevisDIR`" -c=`"$script:ba2`""
    }
    Write-Output "Done!"
    CreateZip
}
function CreateZip {
    $zipFilePath = "$script:data\ToastPRP\GeneratedFiles\$EXT.zip"
    $filesToCompress = "$script:data\$ESP", "$script:data\$EXT - Main.ba2", "$script:data\$EXT - Geometry.csg", "$script:data\$EXT.cdx"
    # Use 7-zip to compress files
    & 7z a -mx=9 -mmt=ON "$zipFilePath" $filesToCompress
    Write-Output "File saved to $zipFilePath"
    Remove-Item $filesToCompress -Force
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

    $promptString = "Enter the number of the function you want to start from (0-$($functions.Count - 1)):`n"
    $promptString += ($functions | ForEach-Object { "$($functions.IndexOf($_)). $_`n" }) -join ""

    $startFunctionInt = 0  # Declare and initialize $startFunctionInt

    do {
        $startFunction = Read-Host -Prompt $promptString
    } while (-not [int]::TryParse($startFunction, [ref]$startFunctionInt) -or $startFunctionInt -lt 0 -or $startFunctionInt -ge $functions.Count)

    for ($i = $startFunctionInt; $i -lt $functions.Count; $i++) {
        $functionName = $functions[$i]
        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
            & $functionName
        } else {
            Write-Host "Function '$functionName' does not exist."
        }
    }
}

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
$introText
$text = "Welcome to CannibalToast's Previsbines Automation Script; Stay Toasty!`n`n"
$delayMilliseconds = 10
for ($i = 0; $i -lt $text.Length; $i++) {
    $char = $text[$i]
    Write-Host -NoNewline $char
    Start-Sleep -Milliseconds $delayMilliseconds
}

try {
    MoveScriptToCorrectDirectory
    DLBSArch
    QueryESP
    Backup-ESP
    Execute
} catch {
    Write-Host "An error occurred:$_"
} finally {
    Write-Host "Previsbines automation completed successfully!"
    if ($script:transcriptActive) {
        Stop-Transcript
    }
}
