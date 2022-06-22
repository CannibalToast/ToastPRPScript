Write-Host @"
"CannibalToast's Previsbines Automation Script | HUGE thank you to Soul on discord for helping me make sense of powershell!"
Stay Toasty!
PLEASE MAKE SURE THAT CK FIXES IS INSTALLED FROM HERE: https://www.nexusmods.com/fallout4/mods/51165
This script is running under the assumption that all prerequisite steps such as:
Running this in Mod Organizer 2 and this script is in the fallout 4 install directory
Creating ESP
Then the running of the following scripts in xedit:
Applying Precalc scipt
All "No Previs" Flags have been removed
Applying Material Swap script
Applying Version control script
Have all been completed
Please reference the full guide with links to all resources here: https://diskmaster.github.io/ModernPrecombines/MANUAL
----------------------------------------------------------------------------------------------------------------------
"@
#Ask for ESP Name
$ESP = Read-Host "Please type in the EXACT file name WITHOUT the .esp extension"
Write-Host "ESP Name: $ESP.esp"

#Ask for xedit directory
$xEdit = Read-Host "Please give the FULL directory of where FO4Edit is installed"
Write-Host "xEdit Directory: $xEdit"

#add .enb extension to incompatible enb files
if (Test-Path "d3d11.dll") 
{ Rename-Item -Path "d3d11.dll" -NewName "d3d11.dll.enb"
}
if (Test-Path "d3dcompiler_46e.dll") 
{ Rename-Item -Path "d3dcompiler_46e.dll" -NewName "d3dcompiler_46e.dll.enb"
}
#Set Variables
$CK = $null
$TIMER = "creationkit"

#Find Creation Kit EXEs 
if (Test-Path "f4ck_loader.exe") {
    $CK = "f4ck_loader.exe"
    Write-Host "Found f4ck_loader.exe"
} else {
	if (Test-Path "creationkit.patched.exe") {
    $CK = "creationkit.patched.exe"
    Write-Host "Found Searge's Creation Kit"
   
	} else {
	$CK = "Creationkit.exe"
	Write-Host "f4ck_loader.exe and Searge's Creation Kit not found, using normal CreationKit instead"
}
}

Write-Host "Using $CK for generation"
#Precombine Generation
if ($CK) {
    Write-Host "Generating Precombines..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePrecombined:`"$ESP.esp`" clean all"
    Start-Sleep -Seconds 5
    Get-Process | Where-Object {$_.ProcessName -like "$TIMER*"} | Wait-Process
    Write-Host "Done!`n"
    Write-Host "Press OK in xedit and apply this script to $ESP.esp: 03_MergeCombinedObjects.pas"
    Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList "-quickedit:combinedobjects.esp"
    Get-Process | Where-Object {$_.ProcessName -like "fo4edit"} | Wait-Process
	
#Making Temp BA2
    Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\Meshes`" -c=`".\Data\$ESP - Main.ba2`""
    Get-Process | Where-Object {$_.ProcessName -like "archive2.exe"} | Wait-Process
    Rename-Item -Path ".\data\meshes" -NewName "meshes2"
    Remove-Item -Path ".\Data\CombinedObjects.esp"
	
#Deleting .PSG file
    while (!(Test-Path -Path ".\Data\$ESP - Geometry.csg")) {
        Write-Host "Compressing PSG..."
        Start-Process -FilePath "creationkit.exe" -ArgumentList "-CompressPSG:`"$ESP.esp`""
        Start-Sleep -Seconds 5
        Get-Process | Where-Object {$_.ProcessName -like "$TIMER*"} | Wait-Process
        Write-Host "Done!`n"

        if (Test-Path ".\Data\$ESP - Geometry.csg") {
            Remove-Item -Path ".\Data\$ESP - Geometry.psg"
            break
        } else {
            Read-Host "ERROR!!! PSG COMPRESSION FAILED!!!"
        }
    }
	
#CDX Generation
    Write-Host "Generating CDX..."
    Start-Process -FilePath $CK -ArgumentList "-buildcdx:`"$ESP.esp`" clean all"
    Start-Sleep -Seconds 5
    Get-Process | Where-Object {$_.ProcessName -like "$TIMER*"} | Wait-Process
    Write-Host "Done!`n"
	
#Preivs Generation
    Write-Host "Generating PreVis..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePreVisdata:`"$ESP.esp`" clean all"
    Start-Sleep -Seconds 5
    Get-Process | Where-Object {$_.ProcessName -like "$TIMER*"} | Wait-Process
    Write-Host "Done!`n"
    Write-Host "Press OK in xedit and apply this script to $ESP.esp: MergePrevis"
    Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList "-quickedit:previs.esp"
    Get-Process | Where-Object {$_.ProcessName -like "fo4edit"} | Wait-Process
	
#Removing .enb Extension from ENB Files

if (Test-Path "d3d11.dll.enb") 
{ Rename-Item -Path "d3d11.dll.enb" -NewName "d3d11.dll"
}
if (Test-Path "d3dcompiler_46e.dll.enb") 
{ Rename-Item -Path "d3dcompiler_46e.dll.enb" -NewName "d3dcompiler_46e.dll"
}
	#Making final BA2
    Write-Host "Creating .BA2 Archive from files..."
    Rename-Item -Path ".\data\meshes2" -NewName "meshes"
     Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\vis,.\data\meshes`" -c=`".\Data\$ESP - Main.ba2`""
     Start-Sleep -Seconds 5
     Get-Process | Where-Object {$_.ProcessName -like "archive2.exe"} | Wait-Process
     #Optional second uncompressed BA2 option. Just remove the #'s below 
	Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\vis,.\data\meshes`" -compression=None -c=`".\Data\$ESP - Mainc.ba2`""
	Start-Sleep -Seconds 5
	Get-Process | Where-Object {$_.ProcessName -like "archive2.exe"} | Wait-Process
	
    Remove-Item -Path ".\data\vis" -Recurse
    Remove-Item -Path ".\data\meshes" -Recurse
	Remove-Item -Path ".\Data\PreVis.esp"
    Write-Host "Done!`n"
    Read-Host "Thank you for using my script! You may close it now. Stay Toasty!"
} else {
    Write-Host "Failed to find f4ck_loader.exe or creationkit.exe"
}
exit