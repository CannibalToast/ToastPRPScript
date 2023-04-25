Write-Output @"
"CannibalToast's Previsbines Automation Script | HUGE thanks to Soul on discord for helping me make sense of powershell!"
PLEASE MAKE SURE THE LATEST VERSION OF CK FIXES IS INSTALLED FROM HERE: https://www.nexusmods.com/fallout4/mods/51165

This script is running under the assumption that all prerequisite steps such as:
Running this in Mod Organizer 2 & this script is in the fallout 4 install directory
Creating ESP
Then the following have been completed:

1. Precalc script
2. MAKE SURE ALL "No Previs" FLAGS HAVE BEEN REMOVED FROM CELLS
3. Apply Material Swap script
4. Apply Version control script
Have all been completed

Please reference full guide with links to all resources here: https://diskmaster.github.io/ModernPrecombines/MANUAL
Stay Toasty!
_____________________________________________________________________________________________________________________
"@
Add-Type -AssemblyName System.Windows.Forms

function Get-ESP {
    $prompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = "$pwd\data"
        Filter           = "Elder Scrolls Plugin (*.esp)|*.esp"
    }
    if ($prompt.ShowDialog() -eq 'OK') {
        $selectedFile = $prompt.FileName
        if (![string]::IsNullOrEmpty($selectedFile)) {
            $script:ESP = Split-Path $selectedFile -Leaf
            $script:EXT = [System.IO.Path]::GetFileNameWithoutExtension($ESP)
            $logFileName = ".\Data\ToastPRP\Logs\{0}-{1:MM-dd-yyyy-HH-mm}.log" -f $EXT, (Get-Date)
            $logFilePath = Join-Path -Path (Get-Location) -ChildPath $logFileName
            Start-Transcript -Path $logFilePath -Append
            $backupChoice = Read-Host "Do you want to create a backup of the ESP file before proceeding? (Y/N)"
            if ($backupChoice.ToLower() -eq "y") {
                $backupPath = ".\Data\ToastPRP\ESP_Backups"
                if (!(Test-Path $backupPath)) {
                    New-Item -ItemType Directory -Path $backupPath | Out-Null
                }
                Copy-Item -Path $selectedFile -Destination "$backupPath\"
                Write-Output "Backup of $ESP created in $backupPath"
            }
        }
        else {
            Write-Warning "No file selected. Please select a file and try again."
            return
        }
    }
    else {
        Write-Warning "File selection dialog was cancelled. Exiting the script."
        return
    }
}



Get-ESP
function Rename-Texture {
    $textureFiles = Get-ChildItem -Path ".\Data" -Filter "* - Textures*.ba2*" -Recurse
    foreach ($file in $textureFiles) {
        $newExtension = if ($file.Extension -eq '.ba2') { '.ba22' } else { '.ba2' }
        Rename-Item -Path $file.FullName -NewName ($file.Name -replace "\$($file.Extension)$", $newExtension)
    }
}

function Invoke-CK([string]$Argument) {
    $script:CK = (Test-Path "f4ck_loader.exe") ? "f4ck_loader.exe" : "CreationKit.exe"
    $startTime = Get-Date
    Start-Process -FilePath $CK -ArgumentList $Argument -Wait
    Write-Output "Completed in $(New-TimeSpan -Start $startTime -End (Get-Date))."
}
function Invoke-xEdit ([string]$Argument) {
    Start-Process -FilePath $script:xEdit -ArgumentList $Argument -Wait
}
function Invoke-Archive2([string]$Argument) {
    $script:Archive2 = "./tools/archive2/archive2.exe"
    $script:UNPACK = '"./data/{0} - Main.ba2" -e=".\data"' -f $EXT
    $script:PACK = '-c=`"./Data/{0} - Main.ba2`"" -Wait' -f $EXT
    Start-Process -FilePath $Archive2 -ArgumentList $Argument -Wait
}
function Precombines {
    # Remove all files in the Precombined directory
    Remove-Item -Path "$pwd\Data\Meshes\Precombined\*" -Recurse
    Write-Output "Generating Precombines..."
    #Add $ESP to Json file right before generation as intended.
    UpdateEspInJson
    # Generate precombined meshes
    Invoke-CK -Argument "-GeneratePrecombined:`"$ESP`" clean all"
    # Check if CombinedObjects.esp exists
    $combinedObjectsPath = ".\data\CombinedObjects.esp"
    if (Test-Path $combinedObjectsPath) {
        Write-Output "Launching xEdit for you!"
        Start-Process -FilePath ./presskeys.vbs
        # Run script to merge combined objects and check
        Invoke-xEdit -Argument "-script:Batch_FO4MergeCombinedObjectsAndCheck.pas -nobuildrefs -Mod:$ESP" -Wait    
    } else {
        Write-Output "CombinedObjects.esp Not found, Relaunching xEdit"
        Stop-Process $script:xEdit
        Start-Process -FilePath ./presskeys.vbs
        # Run script to merge combined objects and check
        Invoke-xEdit -Argument "-script:Batch_FO4MergeCombinedObjectsAndCheck.pas -nobuildrefs -Mod:$ESP" -Wait
    }
    # Remove CombinedObjects.esp
    Remove-Item -Path $combinedObjectsPath
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

function Previs {
    Rename-Texture
    Write-Output "Generating Previs Data..."
    Invoke-CK -Argument "-GeneratePreVisdata:$ESP clean all" -Wait
    Rename-Texture
    $previsPath = ".\data\Previs.esp"
    if (Test-Path $previsPath) {
        Write-Output "Launching xEdit for you!"
        Start-Process -FilePath ./presskeys.vbs
        Invoke-xEdit -Argument "-script:Batch_FO4MergePreVisandCleanRefr.pas -nobuildrefs -Mod:$ESP" -Wait
        Start-Sleep 10
    }
    else {
        Write-Output "CombinedObjects.esp Not found, trying again!"
        Stop-Process $script:xEdit
        Start-Sleep 2
        RStart-Process -FilePath ./presskeys.vbs
        Invoke-xEdit -Argument "-script:Batch_FO4MergePreVisandCleanRefr.pas -nobuildrefs -Mod:$ESP" -Wait
        Start-Sleep 10
    } Remove-Item -Path $previsPath
}

function PackMeshVis {
    Write-Host "Adding New Files to Archive" 
    Invoke-Archive2 -Argument $UNPACK -Wait
    Invoke-Archive2 -Argument ('".\data\Vis,.\data\Meshes\Precombined" -c=".\\Data\\{0} - Main.ba2"' -f $EXT) -Wait
    Remove-Item -Path "$pwd\Data\Vis\", "$pwd\Data\Meshes\Precombined\*" -Recurse
}
function ReadJson {
    $script:jsonFile = "ToastPRP.json"
    if (!(Test-Path $jsonFile)) {
        $script:Data = @{
            "xEditPath" = $null;
            "ESP-WIP"   = @()
        }
        $Data | ConvertTo-Json -Depth 100 | Set-Content $jsonFile
    }
    $script:jsonContent = Get-Content $jsonFile | ConvertFrom-Json
    $script:xEdit = $jsonContent.xEditPath
    if (!$xEdit -or !(Test-Path $xEdit)) {
        $xeditPrompt = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            Filter = "xEdit executable (*.exe)|*.exe";
            Title  = "Select the xEdit executable"
        }
        if ($xeditPrompt.ShowDialog() -eq 'OK') {
            $xEdit = $xeditPrompt.FileName
            $jsonContent.xEditPath = $script:xEdit
            $jsonContent | ConvertTo-Json -Depth 100 | Set-Content $jsonFile
            Write-Output "xedit.exe path added to $jsonFile"
        }
    }
    else {
        Write-Output "xedit.exe path found in $jsonFile"
    }
}

function ExecuteSelectedFunction($startFunction) {
    $functions = @(
        { Precombines },
        { PSGCompression },
        { PackMesh },
        { GenerateCDX },
        { Previs },
        { PackMeshVis }
    )

    for ($i = [int]$startFunction - 1; $i -lt $functions.Count; $i++) {
        & $functions[$i]
    }
}


function Choice {
    ReadJson
    Write-Output "ESP value: $ESP"
    Write-Output "ESP present in JSON: $($ESP -in $jsonContent.'ESP-WIP')"
    
    if ($ESP -in $jsonContent.'ESP-WIP') {
        $startFunction = Read-Host -Prompt @"
Enter the number of the function you want to start from (1-7):
1. Precombines
2. PSGCompression
3. PackMesh
4. GenerateCDX
5. Previs
6. PackMeshVis
"@
    }
    else { $startFunction = 1 }
    
    ExecuteSelectedFunction($startFunction)
}
function UpdateEspInJson {
    $jsonFile = 'ToastPRP.json'
    $jsonContent = Get-Content $jsonFile -Raw | ConvertFrom-Json
    if ($ESP -notin $jsonContent.'ESP-WIP') {
        $jsonContent.'ESP-WIP' += $ESP
        $jsonContent | ConvertTo-Json -Depth 100 | Set-Content $jsonFile
        Write-Host "ESP value $ESP added to $jsonFile"
    }
}
function CreateZip {
    $destinationPath = ".\data\ToastPRP\GeneratedFiles"
    if (!(Test-Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath | Out-Null
    }

    $zipFileName = "$EXT.zip"
    $zipFilePath = Join-Path -Path $destinationPath -ChildPath $zipFileName
    $sourceFiles = @(
        ".\Data\$ESP",
        ".\Data\$EXT - Main.ba2",
        ".\Data\$EXT - Geometry.csg",
        ".\Data\$EXT.cdx"
    )

    Compress-Archive -Path $sourceFiles -DestinationPath $zipFilePath
    Write-Output "Generated zip file saved to $zipFilePath"

    if (Test-Path $zipFileName)
    { Remove-Item $sourceFiles }
    else {
        Write-Output "Error, Zip file not detected"
        return
    }
}

# Check if PressKeys.vbs exists
$vbsScriptPath = "PressKeys.vbs"

if (!(Test-Path $vbsScriptPath)) {
    # Create PressKeys.vbs if it doesn't exist
    $vbsContent = @"
Option Explicit
Dim WshShell, objFSO

Set WshShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

WScript.Sleep 10000 ' Wait for 10 seconds (10000 milliseconds)

WshShell.SendKeys "{PGDN}" ' Press Page Down key
WScript.Sleep 100 ' Small delay between key presses

WshShell.SendKeys " " ' Press Space key
WScript.Sleep 100 ' Small delay between key presses

WshShell.SendKeys "{ENTER}" ' Press Enter key
"@

    Set-Content -Path $vbsScriptPath -Value $vbsContent
}

try {
    Choice
    UpdateEspInJson
    CreateZip
}
finally {
    Write-Host "Previsbines automation completed successfully!"
    Stop-Transcript
}
