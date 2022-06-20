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

echo Generating Precombines...
START /WAIT CreationKit.exe -GeneratePrecombined:"%ESP%.esp" clean all
echo Done!
echo Apply this script to %ESP%.esp in xedit: 03_MergeCombinedObjects
echo Press a key ONLY AFTER applying script

Pause>nul
del .\Data\CombinedObjects.esp

echo Compressing PSG...
START /WAIT CreationKit.exe -CompressPSG:"%ESP%.esp"
echo Done!

IF EXIST "\data\%ESP% - Geometry.csg" (del "\data\%ESP% - Geometry.psg") ELSE (echo ERROR!!! PSG COMPRESSION FAILED && pause)

echo Generating CDX
START /WAIT CreationKit.exe -BuildCDX:"%ESP%.esp"
echo Done!
echo:
echo Generating Previs Data...
START /WAIT CreationKit.exe -GeneratePrevisData:"%ESP%.esp"
echo Done!
echo:
echo:
echo Creating .BA2 Archive from Files...
START /WAIT ./tools/archive2/archive2 ".\Data\Meshes" -c=".\Data\%ESP% - Main.ba2"
.\data\meshes,.\data\vis -recurse
echo Done!
echo Please Apply the script in xedit called: MergePrevis
echo Thank you for using my script! You may close it now. Stay Toasty!!
pause>nul