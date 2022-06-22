@echo off
echo "CannibalToast's Previsbines Automation Script"
echo Stay Toasty!
echo PLEASE MAKE SURE THAT CK FIXES IS INSTALLED FROM HERE: https://www.nexusmods.com/fallout4/mods/51165
echo This script is running under the assumption that all prerequisite steps such as:
echo Running this in Mod Organizer 2 and this script is in the fallout 4 install directory
echo Creating ESP
echo Then the running of the following scripts in xedit:
echo Applying Precalc scipt
echo All "No Previs" Flags have been removed
echo Applying Material Swap script
echo Applying Version control script
echo Have all been completed
echo Please refrence the full guide with links to all resources here: https://diskmaster.github.io/ModernPrecombines/MANUAL
echo ----------------------------------------------------------------------------------------------------------------------
set /p ESP= Please type in the EXACT file name WITHOUT the .esp extension:

echo ESP Name is: %ESP%.esp

set /p xEdit= Please give the FULL directory of where FO4Edit is installed:

IF EXIST "f4ck_loader.exe" (
    IF EXIST "creationkit.patched.exe" (
        set "CK=f4ck_loader.exe"
        set "timer=creaitonkit.patched.exe"
        echo f4ck_loader and Searge's CreationKit patch detected! Using those
    ) else (
        set "CK=f4ck_loader.exe"
        set "timer=creaitonkit.exe"
        echo f4ck_loader found! Using that!
    )
) else (
    set "CK=CreationKit.exe"
    set "timer=creaitonkit.exe"
    echo F4ck_loader not found. Using default CreationKit!
)

:Precombines
echo Generating Precombines...
START /WAIT %CK% -GeneratePrecombined:"%ESP%.esp" clean all
echo Done!
echo press OK and apply this script to %ESP%.esp in xedit: 03_MergeCombinedObjects.pas
pause >nul
cd %xedit%
START /WAIT fo4edit.exe -quickedit:combinedobjects.esp

:TEMPBA2
START /WAIT ./tools/archive2/archive2 ".\Data\Meshes" -c=".\Data\%ESP% - Main.ba2"
rename ".\data\meshes" meshes2

Pause>nul
del .\Data\CombinedObjects.esp

:CompressPSG
echo Compressing PSG...
START /WAIT %CK% -CompressPSG:"%ESP%.esp"
echo Done!

IF EXIST "\data\%ESP% - Geometry.csg" (del "\data\%ESP% - Geometry.psg") ELSE (echo ERROR!!! PSG COMPRESSION FAILED!!! Press a key to try again && pause && goto CompressPSG)

:CDX
echo Generating CDX
START /WAIT %CK% -BuildCDX:"%ESP%.esp"
:LOOP
tasklist /fo csv /fi "IMAGENAME eq %timer%" 2>NUL | find /I /N "%timer%">NUL
IF ERRORLEVEL 1 (
  GOTO CONTINUE
) ELSE (
  Timeout /T 5 /Nobreak
  GOTO LOOP
)
:CONTINUE
echo Done!
echo:
:PREVIS
echo Generating Previs Data...
START /WAIT %CK% -GeneratePrevisData:"%ESP%.esp" clean all
echo Done!
echo:
echo:
:Archive
echo Creating .BA2 Archive from Files...
rename ".\data\meshes2" meshes
START /WAIT ./tools/archive2/archive2 ".\Data\vis,.\data\meshes" -c=".\Data\%ESP% - Main.ba2"
rmdir .\data\vis,.\data\meshes /q /s
echo Done!
echo Please press OK and apply the script in xedit called: MergePrevis
cd %xedit%
START /WAIT fo4edit.exe -quickedit:previs.esp
echo Thank you for using my script! You may close it now. Stay Toasty!!
pause>nul