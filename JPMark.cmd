@echo OFF
pushd %~dp0

:init
set "PATH=%PATH%;E:\PortableApps\Magick"

:prechecks
del /f /q output.png

:main

magick -define jpeg:size=6048x4024 -extract 2480x280+1740+3664  %1 output.png

timeout /t 5

