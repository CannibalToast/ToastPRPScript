#Setup
#==================================================================================================================================================================================================================================================================================================== # 
# Enable verbose output for an entire script
Set-PSDebug -Strict -Trace 0
Start-Transcript
Add-Type -AssemblyName System.Windows.Forms

function Invoke-CK ([string]$Argument) {
    $script:CK = (Test-Path "f4ck_loader.exe") ? "f4ck_loader.exe" : "CreationKit.exe"
    $startTime = Get-Date
    Start-Process -FilePath $CK -ArgumentList $Argument -Wait
    Write-Output "Completed in $(New-TimeSpan -Start $startTime -End (Get-Date))."
}

function Invoke-xEdit {
    $scriptArgument = "-script:$script -nobuildrefs -Mod:$ESP"
    Write-Output "Running xEdit scripts for you!"
    Start-Process -FilePath $xEdit -ArgumentList $scriptArgument
    Start-Sleep 5
    Keypress -KeysToSend "PageDown", "Space", "Enter"
    Start-Sleep 45
    Keypress -KeysToSend "AltF4" -WaitTimeAfterKeys 2
}

function Invoke-Archive2 ([string]$Argument) {
    $script:Archive2 = "./tools/archive2/archive2.exe"
    Start-Process -FilePath $Archive2 -ArgumentList $Argument -Wait
}

$combinedObjectsPath = ".\data\CombinedObjects.esp"
$previsPath = ".\data\Previs.esp"

function Keypress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet("PageDown", "Space", "Enter", "AltF4")]
        [String[]]$KeysToSend,

        [Parameter(Mandatory=$false, Position=1)]
        [Int]$WaitTimeAfterKeys = 0
    )

    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    
    public class WindowHelper {
        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
"@

    # Load the System.Windows.Forms assembly
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    # Wait for 5 seconds
    Start-Sleep -Seconds 5

# Bring FO4Edit to the foreground
#$windowHandle = $xEditProcess.MainWindowHandle
#[WindowHelper]::SetForegroundWindow($windowHandle)

    # Send each key in the array
    foreach ($Key in $KeysToSend) {
        switch ($Key) {
            "PageDown" {
                [System.Windows.Forms.SendKeys]::SendWait("{PGDN}")
            }
            "Space" {
                [System.Windows.Forms.SendKeys]::SendWait(" ")
            }
            "Enter" {
                [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
            }
            "AltF4" {
                [System.Windows.Forms.SendKeys]::SendWait("%{F4}")
            }
        }

        # Wait for 100 milliseconds after each keypress
        Start-Sleep -Milliseconds 100
    }

    # Wait for the specified amount of time after the keys are sent
    Start-Sleep -Seconds $WaitTimeAfterKeys
}


function QueryESP {
# Ask if the user is using their own .esp file
$useOwnEsp = Read-Host "Are you using your own .esp file? (y/n)"

if ($useOwnEsp -eq "y") {
    # Call the Get-ESP function 
    Write-Output "Please choose the name of your .esp file."
    Get-ESP 
    } else {
    # Open xEdit using Start-Process with specified arguments
    $xEditPath = $jsonContent.xEdit
    $arguments = "-script:FO4Check_PreVisbines.pas -Full -autoexit"
    $xEditProcess = Start-Process -FilePath $xEditPath -ArgumentList $arguments -PassThru

    Keypress -KeysToSend "Enter" -WaitTimeAfterKeys 1800
    
    # Close xEdit window gracefully
    $xEditProcess.CloseMainWindow()
    $xEditProcess.WaitForExit()

    # Prompt the user to rename xPrevisPatch.esp
    $script:ESP = Read-Host "Please enter the new name for xPrevisPatch.esp"

    # Rename xPrevisPatch.esp to the specified name
    Rename-Item -Path "./data/xPrevisPatch.esp" -NewName "$script:ESP"
    if (-not ($script:ESP.EndsWith(".esp"))) {
        $script:ESP = $script:ESP -replace '\.[^.]+$','.esp'
    }

    # Store the new name in a variable
    $script:EXT = [System.IO.Path]::GetFileNameWithoutExtension($ESP)
}
}

function Backup-ESP {
    $backupPath = "$PSScriptRoot\Data\ToastPRP\ESP_Backups"
    $backupFilePath = Join-Path -Path $backupPath -ChildPath $ESP

    New-Item -ItemType Directory -Path $backupPath -Force
    Copy-Item -LiteralPath $selectedFile -Destination $backupFilePath -Force

    if (!(Test-Path $backupFilePath)) {
        Write-Output "Backup of $ESP created in $backupPath"
    }
    else {
        Write-Output "Backup of $ESP already exists in $backupPath. Overwriting..."
    }
}

function Get-ESP {
    $prompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = "$pwd\data"
        Filter           = "Elder Scrolls Plugin (*.esp)|*.esp"
    }
    if ($prompt.ShowDialog() -eq 'OK') {
        $selectedFile = $prompt.FileName
        if (![string]::IsNullOrEmpty($selectedFile)) {
            $fileInfo = Get-Item -Path $selectedFile
            $script:ESP = $fileInfo.Name
            $script:EXT = [System.IO.Path]::GetFileNameWithoutExtension($ESP)
            $logFileName = Join-Path $PSScriptRoot "Data\ToastPRP\Logs\$EXT-{0:MM-dd-yyyy-HH-mm}.log" -f (Get-Date)

            Write-Output "Logging to: $logFileName"
            Write-Output "Performing backup for: $ESP"
        }
    }
}

function Read-Json {
    $script:jsonFile = "ToastPRP.json"
    $jsonContent = [ordered]@{
        'ESP-WIP' = @()
        'xEdit'   = $null
    }

    if (Test-Path $jsonFile) {
        $jsonContent = Get-Content $jsonFile -Raw | ConvertFrom-Json
        if ($null -eq $jsonContent) {
            $jsonContent = [PSObject]::new()
        }
        if ($null -eq $jsonContent.'ESP-WIP') {
            $jsonContent | Add-Member -MemberType NoteProperty -Name 'ESP-WIP' -Value @()
        }
        if ($null -ne $jsonContent.'xEdit') {
            $script:xEdit = $jsonContent.'xEdit'
        }
        else {
            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Title = "Select xEdit.exe file"
            $fileDialog.Filter = "xEdit (*.exe)|*.exe"
            $result = $fileDialog.ShowDialog()
            if ($result -eq 'OK') {
                $xEditFilePath = $fileDialog.FileName
                $jsonContent | Add-Member -MemberType NoteProperty -Name 'xEdit' -Value $xEditFilePath -Force
            }
        }
    }

    $jsonContent | ConvertTo-Json -Depth 100 | Set-Content $jsonFile
    return $jsonContent
}

function Update-JsonWithEspAndXEditPath {
    param()

    # Read the JSON file content
    $jsonContent = Read-Json

    # Check if xEdit path is already present in the JSON file
    if (![string]::IsNullOrEmpty($jsonContent.'xEdit')) {
        $xEditPath = $jsonContent.'xEdit'
        Write-Host "Found xEdit path in JSON file: $xEditPath"
    }
    else {
        if ($xeditPrompt.ShowDialog() -eq 'OK') {
            # Search for xEdit executable in the selected directory
            $xEditPath = Get-ChildItem -Path $xeditPrompt.SelectedPath -Filter "xEdit.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if (![string]::IsNullOrEmpty($xEditPath)) {
                # Update JSON content with xEdit path
                $jsonContent.'xEdit' = $xEditPath
                Write-Host "xEdit path not found in JSON file... Amending JSON file..."
                Write-Host "xEdit path saved to $jsonFile"
            }
            else {
                Write-Host "xEdit executable not found in the selected directory."
            }
        }
        else {
            Write-Host "xEdit path not found in JSON file and no directory selected."
        }
    }

    # Check if ESP value is already present in the JSON file
    if ($ESP -notin $jsonContent.'ESP-WIP') {
        # Add ESP value to JSON content
        $jsonContent.'ESP-WIP' += $ESP
        Write-Host "ESP value $ESP added to $jsonFile"
    }

    # Convert JSON content back to JSON format and save to file
    $jsonContent | ConvertTo-Json -Depth 100 | Set-Content $jsonFile

    # Assign xEdit path to calling script variable
    $xEditPath = $script:xEdit
}

#Beginning of execution 
#==================================================================================================================================================================================================================================================================================================== # 

function Precombines {
    $script:script="Batch_FO4MergeCombinedObjectsAndCheck.pas"
    Remove-Item -Path "$pwd\Data\Meshes\Precombined\*" -Recurse -ErrorAction SilentlyContinue
    Update-JsonWithEspAndXEditPath
    Write-Output "Generating Precombines..."
    Invoke-CK -Argument "-GeneratePrecombined:`"$ESP`" clean all" -Wait
    if (!(Test-Path $combinedObjectsPath)) {
        Write-Output "CombinedObjects.esp Not found, restart the process. Make sure to delete any meshes that were generated by the script. Exiting..."
        exit 1
    } else {
        Invoke-xEdit
    }
}

function PSGCompression {
    Write-Output "Compressing PSG..."
    Invoke-CK -Argument "-CompressPSG:$ESP"
    if (!(Test-Path ".\Data\$EXT - Geometry.csg")) {
        Write-Warning "COMPRESSED GEOMETRY NOT FOUND! USING UNCOMPRESSED"
    }
    else { 
        Remove-Item -Path ".\Data\$EXT - Geometry.psg"
        Write-Output "Done!`n"
    }    
}

function PackMesh {
    Write-Output "Making Archive of Files to accelerate generation..."
    Invoke-Archive2 -Argument "`".\Data\Meshes\Precombined`" -c=`".\Data\$EXT - Main.ba2`"" -Wait
    Write-Output Done!
    Remove-Item -Path "$pwd\Data\Meshes\Precombined\*" -Recurse
} 

function GenerateCDX { 
    Write-Output "Generating Cell Index (CDX)..."
    Invoke-CK -Argument "-buildcdx:$ESP clean all" -Wait
    Write-Output "Done!"
}

function Rename-Texture {
    $textureFiles = Get-ChildItem -Path ".\Data" -Filter "* - Textures*.ba2*" -Recurse
    foreach ($file in $textureFiles) {
        $newExtension = if ($file.Extension -eq '.ba2') { '.ba22' } else { '.ba2' }
        Rename-Item -Path $file.FullName -NewName ($file.Name -replace "\$($file.Extension)$", $newExtension)
    }
}

function Previs {
    Rename-Texture
    $script:script="Batch_FO4MergePreVisandCleanRefr.pas"
    Write-Output "Generating Previs Data..."
    Invoke-CK -Argument "-GeneratePreVisdata:$ESP clean all" -Wait
    Rename-Texture
    if (!(Test-Path $previsPath)) {
    Write-Output "CombinedObjects.esp Not found, trying again!"
    Invoke-xEdit
    Keypress
    } else {
        Invoke-xEdit
    }
    Remove-Item -Path $previsPath
    Remove-Item -Path $combinedObjectsPath
}

function PackMeshVis {
    Write-Host "Adding New Files to Archive" 
    Invoke-Archive2 -Argument ('".\data\{0} - Main.ba2" -e=".\data"' -f $EXT) -Wait
    Invoke-Archive2 -Argument ('".\data\Vis,.\data\Meshes\Precombined" -c=".\\Data\\{0} - Main.ba2"' -f $EXT) -Wait
    Remove-Item -Path "$pwd\Data\Vis\", "$pwd\Data\Meshes\Precombined\*" -Recurse
}

function CreateZip {
    $script:destinationPath = ".\data\ToastPRP\GeneratedFiles"
    $zipFilePathold = "$EXT.zip.old"
    $zipFilePath = "$destinationPath\$EXT.zip"
    if (Test-Path $zipFilePath) {
        Rename-Item -Path $zipFilePath $zipFilePathold
    }
    Compress-Archive -Path ".\Data\$ESP", ".\Data\$EXT - Main.ba2", ".\Data\$EXT - Geometry.csg", ".\Data\$EXT.cdx" -DestinationPath $zipFilePath
    Write-Output "ZIP file saved to $zipFilePath"
}

$jsonContent = Read-Json

function Choice {
    Write-Host "ESP value: $ESP"
    Write-Host "ESP present in JSON: $($jsonContent.'ESP-WIP' -contains $ESP)"

    if ($ESP -in $jsonContent.'ESP-WIP') {
        $startFunction = Read-Host -Prompt @'
Enter the number of the function you want to start from (0-5):
0. Precombines
1. PSGCompression
2. PackMesh
3. GenerateCDX
4. Previs
5. PackMeshVis
'@

        # Validate user input
        if ($startFunction -match '^[0-5]$') {
            ExecuteSelectedFunction $startFunction
        } else {
            Write-Host "Invalid input. Please enter a number between 0 and 5."
        }
    } else {
        ExecuteSelectedFunction 0
    }
}

## choose and misc Logic
#==================================================================================================================================================================================================================================================================================================== #
function ExecuteSelectedFunction([int]$startFunction) {
    $functions = @(
        "Precombines",
        "PSGCompression",
        "PackMesh",
        "GenerateCDX",
        "Previs",
        "PackMeshVis"
    )
    $functionsCount = $functions.Count

    if ($startFunction -ge 0 -and $startFunction -lt $functionsCount) {
        for ($i = $startFunction; $i -lt $functionsCount; $i++) {
            $functionName = $functions[$i]
            if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                & $functionName
            } else {
                Write-Host "Function '$functionName' does not exist."
            }
        }
    } else {
        Write-Host "Invalid start function value"
    }
}

    
$introText = @"
HUGE thanks to Soul on discord for helping me make sense of powershell!

THIS SCRIPT IS ASSUMING THAT...
You're using Mod Organizer 2 & this script is in the fallout 4 install directory and...

THE PJM SCRIPT HAS BEEN RAN AND THE RESULTING ESP FILE IS WHATS BEING MODIFIED

Please reference the links to all needed resources here:
https://diskmaster.github.io/ModernPrecombines/MANUAL
https://www.nexusmods.com/fallout4/mods/69978
https://www.nexusmods.com/fallout4/mods/51165
____________________________________________________________________________________________________
"@
    
    $text = "Welcome to CannibalToast's Previsbines Automation Script; Stay Toasty!`n`n"
    
    Write-Output @"
$introText
"@
    
$delayMilliseconds = 10
    for ($i = 0; $i -lt $text.Length; $i++) {
        $char = $text[$i]
        Write-Host -NoNewline $char
        Start-Sleep -Milliseconds $delayMilliseconds
    }
    try {
        QueryESP
        Choice
        CreateZip
    }
    finally {
        Write-Host "Previsbines automation completed successfully!"
        Stop-Transcript
    }