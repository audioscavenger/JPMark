@echo OFF
pushd %~dp0
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: * requisites:
:: - jpegtran https://jpegclub.org/jpegtran/                            Jpeg lossless operations
:: - iMagick  https://www.imagemagick.org/script/download.php#windows   Portable Win64 static at 16 bits-per-pixel component.
::
:: the sample image is 6048x4024 JPEG, quality: 91, subsampling ON (2x1)
:: we want the watermark to be centered at roughly the bottom with:
:: wwidth   = width * 40 / 100 modulo 8
:: wheight  = height * 7 / 100 modulo 8
:: wleft    = (width - wwidth) /2 modulo 8
:: wtop     = (height - wheight) + 80 modulo 8
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:init
set author=AudioscavengeR
set authorEmail=dev@derewonko.com
set version=1.0.0

:: codepage 65001 is pretty much UTF8
chcp 65001 >NUL
set DEBUG=
set extract=extract.png
set watermark=watermark.jpg

:defaults
set Scale=100
set alpha=0.2
set fontColor=255,255,255
:: 99.99% of jpeg have a 8x8 block DCT with 2x1 sample factor, but this will be extracted from the original jpeg anyway
set hsample=16
set vsample=8

::::::::::::::::::::::::::::::::::::::::::::: customize your own values here :::::::::::::::::::::::::::::::::::::::::::::
:custom
:: it is critical that you provide here the path to jpegtran and imagick here
set "PATH=%PATH%;E:\PortableApps\Magick;E:\wintools\multimedia\jpegtran"
set text=©^&ric photography
set font=Romantica-RpXpW.ttf
:: watermark width and height as a percentage of your pictures
set wwidthPct=30
set wheightPct=9
:: Point_Size and wwidth really depends on the font type and the height of the watermark; play with textScale to see if it fits; the example Romantica-RpXpW.ttf provided is a bit special
set textScale=80
:: output filename, cannot be the same as the original file
set outputFile=%~dpn1-C%~x1
::::::::::::::::::::::::::::::::::::::::::::: customize your own values here :::::::::::::::::::::::::::::::::::::::::::::

:prechecks
call :set_colors
del /f /q %extract% %watermark% 2>NUL

:main
echo Processing %~nx1 ...

call :getJpegInfo %1
call :getWSIZE
call :calculatePoint_Size

:: we need a png extract for transparency, bro
call :extractMagick %1 %extract%
REM call :extractJpegtran %1 %extract%
call :genWatermark %extract% %watermark%
call :pasteWatermark %watermark% %1 %outputFile%

goto :end



:getWSIZE
set /A wwidth   = width * wwidthPct / 100
set /A wheight  = height * wheightPct / 100
call :logDEBUG WSIZE    =%wwidth%x%wheight%

set /A wwidth   = wwidth - (wwidth %% hsample)
set /A wheight  = wheight - (wheight %% vsample)

set /A wleft    = (width - wwidth) / 2
set /A wtop     = (height - wheight) - 80
set /A wleft    = wleft - (wleft %% hsample)
set /A wtop     = wtop - (wtop %% vsample)

call :logDEBUG WSIZE  m8=%wwidth%x%wheight%
call :logDEBUG WPOS     =%wleft%+%wtop%

set WSIZE=%wwidth%x%wheight%
set "WPOS=%wleft%+%wtop%"
goto :EOF


:getJpegInfo
:: https://imagemagick.org/script/identify.php
:: https://imagemagick.org/script/escape.php
:: magick identify Filename[frame #] image-format widthxheight page-widthxpage-height+x-offset+y-offset colorspace user-time elapsed-time
:: IT WORKS!!!! but you have to define the size of the layers. Both commands are equivalent:
rem FOR /F "tokens=1,2 USEBACKQ" %%a IN (`magick identify -format "%%[fx:w]x%%[fx:h] %%[jpeg:sampling-factor]" %1`) DO SET SIZE=%%a %%b
rem FOR /F "tokens=1,2 USEBACKQ" %%a IN (`magick identify -format ""%%wx%%h %[jpeg:sampling-factor]" %1`) DO SET SIZE=%%a %%b
FOR /F "tokens=1-4 USEBACKQ" %%a IN (`magick identify -format "%%[fx:w] %%[fx:h] %%[jpeg:sampling-factor] %%Q" %1`) DO set "width=%%a" & set "height=%%b" & set "sampling=%%c" & set "Quality=%%d"

set SIZE=%width%x%height%
for /f "tokens=1"   %%a in ("%sampling:,= %") DO set "samplingFactor=%%a"
for /f "tokens=1,2" %%a in ("%samplingFactor:x= %") DO set /A "hsample=%%a * 8" & set /A "vsample=%%b * 8"

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

:extractMagick input output
magick -define jpeg:size=%SIZE% -extract %WSIZE%+%WPOS% %1 %2
goto :EOF

:genWatermark input output
set JPEG_OPTIONS=-sampling-factor %samplingFactor% -quality %Quality%

magick convert %1 %OPTIONS% ^
%resize% ^
-gravity Center ^( -size %WSIZE% xc:none -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%alpha%) -strokewidth 7 -annotate 0 "%text%" -blur 0x1 ^) ^
-composite -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,1) -stroke none      -annotate 0 "%text%" ^
%JPEG_OPTIONS% ^
%2

goto :EOF

:extractJpegtran input output
:: https://stackoverflow.com/questions/37560777/how-can-i-losslessly-crop-a-jpeg-in-r/37612027
REM The -crop switch specifies the rectangular subarea WxH+X+Y, 
REM and -optimize is an option for reducing file size without quality loss by optimizing the Huffman table. 
REM For a complete list of switches see jpegtran -help.
:: jpegtran jpegjoin https://jpegclub.org/jpegtran/
:: jpegcrop http://sylvana.net/jpegcrop/
:: lossless croping: http://www.ben.com/jpeg/

REM DEBUG: set SIZE=6048x4024
REM DEBUG: set WSIZE=1814x362
REM DEBUG: set WSIZE=1808x360
REM DEBUG: set WPOS=2120+3584

REM jpegtran -crop %newWidth%x%newHeight%+0+0 -optimize %1 %2
REM jpegtran -crop %WSIZE%+%WPOS% DZ6_6045.JPG extract.jpg
jpegtran -crop %WSIZE%+%WPOS% -optimize %1 %2

goto :EOF

:pasteWatermark watermark input output
jpegtran -drop +%WPOS% %1 -optimize %2 %3
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
IF DEFINED DEBUG %outputFile%
REM timeout /t 5

