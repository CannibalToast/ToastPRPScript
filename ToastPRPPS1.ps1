Write-Host @"
"CannibalToast's Previsbines Automation Script | HUGE thanks to Soul on discord for helping me make sense of powershell!"
Stay Toasty!
PLEASE MAKE SURE THE LATEST VERSION OF CK FIXES IS INSTALLED FROM HERE: https://www.nexusmods.com/fallout4/mods/51165
This script is running under the assumption that all prerequisite steps such as:
Running this in Mod Organizer 2 & this script is in the fallout 4 install directory
Creating ESP
Then the running of the following scripts in xedit:
Precalc scipt
Apply Material Swap
Apply Version control
Have all been completed
MAKE SURE ALL "No Previs" FLAGS HAVE BEEN REMOVED FROM CELLS
Please reference full guide with links to all resources here: https://diskmaster.github.io/ModernPrecombines/MANUAL
--------------------------------------------------------------------------------------------------------------------
"@
Do {
	# Yes/No
    Write-Host Did you read ALL of the text above about the requirements for this script?`(y/n`)
    $ANSWER = Read-Host Answer
	Write-Host PLEASE MAKE SURE YOU READ THE TEXT ABOVE BEFORE CONTINUING WITH THIS SCRIPT
}
Until ($ANSWER -eq 'y')


#ESP Name
$ESP = Read-Host "Please type in the EXACT file name WITH the extension"

#EXT
$EXT = [System.IO.Path]::GetFileNameWithoutExtension($ESP)   

#xEdit DIR
$xEdit = Read-Host "Please give the FULL directory of FO4Edit"

#Find Creation Kit EXE(s) 
if (Test-Path "f4ck_loader.exe") {
$CK = "f4ck_loader.exe"
Write-Host "f4ck_loader.exe found" } else { if (Test-Path Creationkit.patched.exe) {
Write-Host " f4ck_loader not found. Using Searge's Patched Creation Kit"
$CK = "Creationkit.patched.exe" } else { $CK = "Creationkit.exe"} Write-Host "Using Default Creaitonkit.exe as no other exe's were found!"
} Write-Host "Using $CK for generation"

if (Test-Path "d3d11.dll,d3dcompiler_46e.dll") {
Rename-Item "d3d11.dll" -NewName "d3d11.dll.enb"
Rename-Item "d3dcompiler_46e.dll" -NewName "d3dcompiler_46e.dll.enb"
}

#STARTING SCRIPT
if ($CK) {
#PC GEN
Write-Host "Generating Precombines..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePrecombined:`"$ESP`" clean all" -wait
    Write-Host "Done!`n" 
	"Launching xEdit for you! Press OK in xedit & apply this script to $ESP.esp: 03_MergeCombinedObjects.pas"
	Timeout /T 3
	Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList '"-nobuildrefs" "-quickedit:CombinedObjects.esp"' -wait

#CompressPSG
        Write-Host "Compressing PSG..."
        Start-Process -FilePath $CK -ArgumentList "-CompressPSG:`"$ESP`"" -wait
        Write-Host "Done!`n"
		if (Test-Path ".\Data\$EXT - Geometry.csg") {
            Remove-Item -Path ".\Data\$EXT - Geometry.psg"
		}
#Temp ARCHIVE
Write-Host "Making Temporary archive of meshes to accelerate generation."
    Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\Meshes`" -c=`".\Data\$EXT - Main.ba2`"" -wait
	Write-Host Done!

#GenerateCDX
Write-Host "Generating CDX..."
    Start-Process -FilePath $CK -ArgumentList "-buildcdx:`"$ESP`" clean all" -wait
    Write-Host "Done!`n"
#GeneratePREVIS
Write-Host "Generating PreVis..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePreVisdata:`"$ESP`" clean all" -wait
    Write-Host "Done!`n""Launching xEdit for you! Press OK in xedit & apply this script to $ESP.esp: 05_MergePrevis.pas"
    Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList '"-nobuildrefs" "-quickedit:PreVis.esp"' -wait

#ARCHIVE
Write-Host "Creating .BA2 Archive from files..."
	Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList '"$EXT - Main.ba2" -e="./"'
    Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\vis,.\data\meshes`" -c=`".\Data\$EXT - Main.ba2`"" -wait
#CLEANUP
Write-Host "Autocleaning ESP..."
	Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList "-qac -autoexit -autoload $ESP" -wait
	Remove-item ".\data\meshes\",".\data\vis\",".\data\PreVis.esp",".\data\CombinedObjects.esp" -Recurse
	
if (Test-Path "d3d11.dll.enb,d3dcompiler_46e.dll.enb") {
Rename-Item "d3d11.dll.enb" -NewName "d3d11.dll"
Rename-Item "d3dcompiler_46e.dll.enb" -NewName "d3dcompiler_46e.dll"
}

Read-Host "Done!'n""Thank you for using my script! You may close it now. Stay Toasty!"
exit
} else { 
Read-Host "Creation Kit not found, Please make sure that you have creation kit intalled and that this file is in the same directory is creationkit.exe"
exit
}