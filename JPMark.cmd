@echo OFF
pushd %~dp0

:: the sample image is 6048x4024 JPEG, quality: 91, subsampling ON (2x1)
:: we want the watermark to be centered at roughly the bottom with:
:: wwidth   = width * 40 / 100 modulo 8
:: wheight  = height * 7 / 100 modulo 8
:: wleft    = (width - wwidth) /2 modulo 8
:: wtop     = (height - wheight) + 80 modulo 8

:init
set "PATH=%PATH%;E:\PortableApps\Magick"
set DEBUG=true
set wwidthPct=40
set wheightPct=8

:prechecks
call :set_colors
del /f /q output.png

:main

call :getSIZE %1
call :getWSIZE

REM magick -define jpeg:size=%SIZE% -extract 2480x280+1740+3664  %1 output.png
magick -define jpeg:size=%SIZE% -extract %WSIZE%+%WPOS%  %1 output.png
goto :end



:getWSIZE
set /A wwidth   = width * wwidthPct / 100
set /A wheight  = height * wheightPct / 100
call :logDEBUG WSIZE    =%wwidth%x%wheight%

set /A wwidth   = wwidth - (wwidth %% 8)
set /A wheight  = wheight - (wheight %% 8)

set /A wleft    = (width - wwidth) / 2
set /A wtop     = (height - wheight) - 80

call :logDEBUG WSIZE  m8=%wwidth%x%wheight%
call :logDEBUG WPOS     =%wleft%x%wtop%

set WSIZE=%wwidth%x%wheight%
set "WPOS=%wleft%+%wtop%"
goto :EOF


:getSIZE
:: IT WORKS!!!! but you have to define the size of the layers. Both commands are equivalent:
rem FOR /F "tokens=* USEBACKQ" %%s IN (`magick getSIZE -format "%%[fx:w]x%%[fx:h]" %1`) DO SET SIZE=%%s
FOR /F "tokens=* USEBACKQ" %%s IN (`magick convert  -ping %1 -format "%%wx%%h" info:`) DO SET SIZE=%%s
echo SIZE=%SIZE%

for /f "tokens=1,2" %%a in ("%SIZE:x= %") DO (
  set width=%%a
  set height=%%b
)
call :logDEBUG SIZE=%SIZE%
goto :EOF

:logDEBUG
IF DEFINED DEBUG echo %m%DEBUG: %*%END%
goto :EOF


:set_colors
set colorCompatibleVersions=-8-8.1-10-2016-2019-
IF DEFINED WindowsVersion IF "%colorCompatibleVersions:-!WindowsVersion!-=_%"=="%colorCompatibleVersions%" exit /b 1

set END=[0m
set HIGH=[1m
set Underline=[4m
set REVERSE=[7m

REM echo [101;93m NORMAL FOREGROUND COLORS [0m
set k=[30m
set r=[31m
set g=[32m
set y=[33m
set b=[34m
set m=[35m
set c=[36m
set w=[37m

REM echo [101;93m NORMAL BACKGROUND COLORS [0m
set RK=[40m
set RR=[41m
set RG=[42m
set RY=[43m
set RB=[44m
set RM=[45m
set RC=[46m
set RW=[47m

goto :EOF
:: BUG: some space are needed after :set_colors



:end
timeout /t 5

