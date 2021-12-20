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
set Scale=100
set extract=extract.png
set watermark=watermark.png
set alpha=0.3
set fontColor=255,255,255

:: Point_Size and wwidth really depends on the font type and the height of the watermark; play with textScale to see if it fits
set textScale=80
set text=^&ric photography
set font=Romantica-RpXpW.ttf
set wwidthPct=30
set wheightPct=9

:prechecks
call :set_colors
del /f /q %extract% %watermark%

:main

call :getSIZE %1
call :getWSIZE
call :calculatePoint_Size

REM magick -define jpeg:size=%SIZE% -extract 2480x280+1740+3664  %1 %extract%
magick -define jpeg:size=%SIZE% -extract %WSIZE%+%WPOS%  %1 %extract%

call :watermark %extract% %watermark%

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


:calculatePoint_Size
set /A Point_Size=wheight * textScale / 100

:: https://www.imagemagick.org/Usage/resize/
set resize=
IF %Scale% NEQ 100 (
  set "resize=-resize %Scale%%%"
  set /A Point_Size=Point_Size * Scale / 100
)

goto :EOF

:watermark input output

magick convert %1 %OPTIONS% ^
%resize% ^
-gravity Center ^( -size %WSIZE% xc:none -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%alpha%) -strokewidth 7 -annotate 0 "%text%" -blur 0x1 ^) ^
-composite -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,1) -stroke none      -annotate 0 "%text%" ^
%QUALITY% ^
%2

REM -gravity %gTOP% -size %SIZE% xc:none -font Impact -pointsize %scaledPoint_Size% -stroke rgba(0,0,0,1) -strokewidth 7 -annotate 0 "%annotateTOP%" -blur 0x1  ^
REM -gravity Center -size %WSIZE% xc:none -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%alpha%) -stroke none -annotate 0 "%text%" -blur 0x1 ^
REM -composite -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,1) -stroke none      -annotate 0 "%text%" ^

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
%watermark%
REM timeout /t 5

