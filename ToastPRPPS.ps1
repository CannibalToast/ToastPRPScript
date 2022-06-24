Write-Host @"
"CannibalToast's Previsbines Automation Script | HUGE thanks to Soul on discord for helping me make sense of powershell!"
Stay Toasty!
PLEASE MAKE SURE THE LATEST VERSION OF CK FIXES IS INSTALLED FROM HERE: https://www.nexusmods.com/fallout4/mods/51165
DOWNLOAD AND DROP ALL OF THE FOLDERS AND FILES INTO THE FALLOUT 4 FOLDER
WHEN PROMPTED SELECT YES TO INSTALL F4CK_LOADER

This script is running under the assumption that all prerequisite steps such as:
Running this in Mod Organizer 2 and this script is in the fallout 4 install directory
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
	# PROMPT FOR USER INPUT
    Write-Host Did you read ALL of the text above about the requirements for this script?`(y/n`)
    Write-Host
    $ANSWER = Read-Host Answer
	Write-Host PLEASE READ THE TEXT ABOVE BEFORE CONTINUING WITH THIS SCRIPT
}
Until ($ANSWER -eq 'y')
#Ask for ESP Name
$ESP = Read-Host "Please type in the EXACT file name WITHOUT the .esp extension"

#Ask for xedit directory
$xEdit = Read-Host "Please give the FULL directory of where FO4Edit is installed"

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
#PRECOMBINE GENERATION
if ($CK) {
    Write-Host "Generating Precombines..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePrecombined:`"$ESP.esp`" clean all" -wait
    Write-Host "Done!`n"
    Write-Host "Hold shift and press OK in xedit and apply this script to $ESP.esp: 03_MergeCombinedObjects.pas 'n"
    Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList "-quickedit:combinedobjects.esp" -wait
#Deleting .PSG file
		while (!(Test-Path -Path ".\Data\$ESP - Geometry.csg")) {
        Write-Host "Compressing PSG..."
        Start-Process -FilePath $CK -ArgumentList "-CompressPSG:`"$ESP.esp`"" -wait
        Write-Host "Done!`n"

        if (Test-Path ".\Data\$ESP - Geometry.csg") {
            Remove-Item -Path ".\Data\$ESP - Geometry.psg"
            break
        } else {
            Read-Host "ERROR!!! PSG COMPRESSION FAILED!!!"
        }
    }
	
#MAKING TEMP BA2
    Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\Meshes`" -c=`".\Data\$ESP - Main.ba2`"" -wait
    Rename-Item -Path ".\data\meshes" -NewName "meshes2"
    Remove-Item -Path ".\Data\CombinedObjects.esp"


	
#CDX Generation
Write-Host "Generating CDX..."
    Start-Process -FilePath $CK -ArgumentList "-buildcdx:`"$ESP.esp`" clean all" -wait
    Write-Host "Done!`n"

#Preivs Generation
	Write-Host "Generating PreVis..."
    Start-Process -FilePath $CK -ArgumentList "-GeneratePreVisdata:`"$ESP.esp`" clean all" -wait
    Write-Host "Done!`n"
    Write-Host "Hold Shift and press OK in xedit and apply this script to $ESP.esp: 05_MergePrevis.pas"
    Start-Process -FilePath "$xEdit\fo4edit.exe" -ArgumentList "-quickedit:previs.esp" -wait


#Making final BA2
Write-Host "Creating .BA2 Archive from files..."
    Rename-Item -Path ".\data\meshes2" -NewName "meshes"
    Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\vis,.\data\meshes`" -c=`".\Data\$ESP - Main.ba2`"" -wait
     #OPTIONAL SECOND UNCOMPRESSED BA2 OPTION. JUST REMOVE THE #'S BELOW 
	 #Start-Process -FilePath ".\tools\archive2\archive2" -ArgumentList "`".\Data\vis,.\data\meshes`" -compression=None -c=`".\Data\$ESP - Mainc.ba2`"" -wait
	Remove-item ".\data\meshes\",".\data\vis\",".\data\previs.esp" -Recurse
    #Write-Host "Done!`n"
    Read-Host "Thank you for using my script! You may close it now. Stay Toasty!"

} else {
    Write-Host "Failed to find f4ck_loader.exe or creationkit.exe"
}

exit