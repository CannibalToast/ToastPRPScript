Write-Host @"
"CannibalToast's Previsbines Automation Script | HUGE thanks to Soul on discord for helping me make sense of powershell!"
Stay Toasty!
PLEASE MAKE SURE THE LATEST VERSION OF CK FIXES IS INSTALLED FROM HERE: https://www.nexusmods.com/fallout4/mods/51165
DOWNLOAD & DROP ALL OF THE FOLDERS & FILES INTO THE FALLOUT 4 FOLDER
IF PROMPTED SELECT YES TO INSTALL F4CK_LOADER

This script is running under the assumption that all prerequisite steps such as:
Running this in Mod Organizer 2 & this script is in the fallout 4 install directory
Creating ESP
Then the running of the following scripts in xedit:
Applying Precalc scipt
All "No Previs" Flags have been removed
Applying Material Swap script
Applying Version control script
Have all been completed
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
$ESP = Read-Host "Please type in the EXACT file name WITHOUT the .esp extension"

#xEdit DIR
$xEdit = Read-Host "Please give the FULL directory of where FO4Edit is installed"

#Verify Script is in CK DIR
if (Test-Path "creationkit.exe") {

Write-Host "Creation Kit found"
} else { 

Read-Host "Creation Kit not found, Please make sure that the script is in the fallout 4 directory and restart this script"
exit
}

#Find Creation Kit EXEs 
if (Test-Path "f4ck_loader.exe") {
    $CK = "f4ck_loader.exe"
    Write-Host "f4ck_loader.exe found"
} else {
Read-Host "f4ck_loader.exe NOT FOUND!!! PLEASE INSTALL CK FIXES AND RESTART THIS SCRIPT"
exit
}
 
Write-Host "Using $CK for generation"

#STARTING SCRIPT
if ($CK) {
#PC GEN
Write-Host "Generating Precombines..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePrecombined:`"$ESP.esp`" clean all" -wait
    Write-Host "Done!`n"
    Write-Host "Hold shift & press OK in xedit & apply this script to $ESP.esp: 03_MergeCombinedObjects.pas"
	Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList "-quickedit:combinedobjects.esp" -wait

#CompressPSG
 while (!(Test-Path -Path ".\Data\$ESP - Geometry.csg")) {
        Write-Host "Compressing PSG..."
        Start-Process -FilePath $CK -ArgumentList "-CompressPSG:`"$ESP.esp`"" -wait
        Write-Host "Done!`n"
		}
		if (Test-Path ".\Data\$ESP - Geometry.csg") {
            Remove-Item -Path ".\Data\$ESP - Geometry.psg"
		}

Write-Host "Making Temporary archive of meshes to accelerate generation."
    Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\Meshes`" -c=`".\Data\$ESP - Main.ba2`"" -wait
    Rename-Item -Path ".\data\meshes" -NewName "meshes2"
	Write-Host Done!
	
Write-Host "Generating CDX..."
    Start-Process -FilePath $CK -ArgumentList "-buildcdx:`"$ESP.esp`" clean all" -wait
    Write-Host "Done!`n"

Write-Host "Generating PreVis..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePreVisdata:`"$ESP.esp`" clean all" -wait
    Write-Host "Done!`n"
    Write-Host "Hold Shift & press OK in xedit & apply this script to $ESP.esp: 05_MergePrevis.pas"
    Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList "-quickedit:previs.esp" -wait

Write-Host "Creating .BA2 Archive from files..."
    Rename-Item -Path ".\data\meshes2" -NewName "meshes"
    Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\vis,.\data\meshes`" -c=`".\Data\$ESP - Main.ba2`"" -wait
	Remove-item ".\data\meshes\",".\data\vis\",".\data\previs.esp",".\data\CombinedObjects.esp" -Recurse
    Read-Host "Thank you for using my script! You may close it now. Stay Toasty!"

exit
}