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
_____________________________________________________________________________________________________________________

"@
Do {
	# Yes/No
    Write-Host Did you read ALL of the text above about the requirements for this script?`(y/n`)
    $ANSWER = Read-Host Answer
	Write-Host PLEASE MAKE SURE YOU READ THE TEXT ABOVE BEFORE CONTINUING WITH THIS SCRIPT
}
Until ($ANSWER -eq 'y')


#V A R I A B L E S
$ESP = Read-Host "Please type in the EXACT file name WITH the extension"

$EXT = [System.IO.Path]::GetFileNameWithoutExtension($ESP)

#$xEdit
If (!(Test-Path "xedit.txt")) { $xEdit = Read-Host "Please input the FULL directory of FO4Edit WITH EXECUTABLE!!! ex. /bla/bla/fo4edit.exe It will be saved for your next launch of my script :)"
New-Item xedit.txt
Set-Content xedit.txt $xEdit } else { $xEdit = get-Content "xedit.txt" }

$Archive2 = "./tools/archive2/archive2"

$UNPACK = '"./data/{0} - Main.ba2" -e=".\data"' -f $EXT

$PACK = "-c=`".\Data\{0} - Main.ba2`"" -f $EXT

$ENB = 'Rename-Item "d3d11.dll" -NewName "d3d11.dll.enb" Rename-Item "d3dcompiler_46e.dll" -NewName "d3dcompiler_46e.dll.enb"'
$BNE = 'Rename-Item "d3d11.dll.enb" -NewName "d3d11.dll" Rename-Item "d3dcompiler_46e.dll.enb" -NewName "d3dcompiler_46e.dll"'

#Find Creation Kit EXE(s) 
if (Test-Path "f4ck_loader.exe") {
$CK = "f4ck_loader.exe"
Write-Host "f4ck_loader.exe found" } else { 
$ENB
if (Test-Path Creationkit.patched.exe) { 
$ENB
Write-Host " f4ck_loader not found. Using Searge's Patched Creation Kit"
$CK = "Creationkit.patched.exe" } else { $CK = "Creationkit.exe"} Write-Host "Using Default Creaitonkit.exe as no other exe's were found!"
} Write-Host "Using $CK for generation"


#STARTING Generation
if ($CK) {
#PC GEN
Write-Host "Generating Precombines..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePrecombined:`"$ESP`" clean all" -wait
    Write-Host "Done!`n" 
	"Launching xEdit for you! Press OK in xedit & apply this script to $ESP: 03_MergeCombinedObjects.pas"
	Start-Process -FilePath $xEdit -ArgumentList '"-nobuildrefs" "-quickedit:CombinedObjects.esp"' -wait
	Remove-item ".\Data\CombinedObjects.esp"
	
#CompressPSG
        Write-Host "Compressing PSG..."
        Start-Process -FilePath $CK -ArgumentList "-CompressPSG:$ESP" -wait
        Write-Host "Done!`n"
		if (Test-Path ".\Data\$EXT - Geometry.csg") {
            Remove-Item -Path ".\Data\$EXT - Geometry.psg"
		} else { Remove-Item -Path ".\data\$ESP",".\data\$EXT.cdx",".\data\$EXT - Geometry.csg",".\data\$EXT - Main.ba2" 
		Read-Host "COMPRESSION FAILED!! ALL GENERATED FILES INCLUDING $ESP HAVE BEEN DELETED TO PREVENT ANOTHER CORRUPTED ATTEMPT! PLEASE RESTART THE PROCESS"
exit
}

#Temp ARCHIVE
Write-Host "Making Archive of Files to accelerate generation..."
    Start-Process -FilePath $Archive2 -ArgumentList "`".\data\meshes`" $PACK" -wait
	Write-Host Done!
	Remove-Item -Path ".\Data\Meshes\" -Recurse
	
#GenerateCDX
Write-Host "Generating Cell Index (CDX)..."
    Start-Process -FilePath $CK -ArgumentList "-buildcdx:$ESP clean all" -wait
    Write-Host "Done!"
	
#Generate PREVIS
Write-Host "Generating PreVis Data..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePreVisdata:$ESP clean all" -wait
    Write-Host "Done!`n""Launching xEdit for you! Press OK in xedit & apply this script to $ESP: 05_MergePrevis.pas"
    Start-Process -FilePath $xEdit -ArgumentList '"-nobuildrefs" "-quickedit:PreVis.esp"' -wait
	Remove-Item -Path ".\Data\PreVis.esp\"
	
#ARCHIVE
	Write-Host "Adding New Files to Archive" 
	Start-Process -FilePath $Archive2 $UNPACK -wait
    Start-Process -FilePath $Archive2 -ArgumentList "`".\data\vis,.\data\meshes`" $PACK" -wait
	Remove-Item -Path ".\Data\Vis\",".\Data\Meshes\" -Recurse
	
#CLEANUP
Write-Host "Cleaning Up The ESP..."
	Start-Process -FilePath $xEdit -ArgumentList "-qac -autoexit -autoload $ESP" -wait
	if (!(Test-Path "f4ck_loader.exe")) {$BNE} 
	
#ZIP
Compress-Archive -Path ".\data\$ESP",".\data\$EXT.cdx",".\data\$EXT - Geometry.csg",".\data\$EXT - Main.ba2" -DestinationPath ".\data\$EXT.zip"
Remove-Item -Path ".\data\$ESP",".\data\$EXT.cdx",".\data\$EXT - Geometry.csg",".\data\$EXT - Main.ba2"

Write-Host "GENERATION COMPLETE!!! All required files are in the .ZIP file created, you can install like any other mod!! Thank you for using my script! You may close it now. Stay Toasty!"
exit
} else { 
Read-Host "Creation Kit not found, Please put this script in the fallout 4 folder"
exit
}