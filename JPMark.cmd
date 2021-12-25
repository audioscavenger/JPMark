@echo OFF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: 
:: JPMark is a lossless JPEG watermarking tool.
:: 
:: How does it work?
:: It extracts a chunk and watermarks it using imagick, then jpegtran drops it back without the whole jpeg being re-encoded at all.
:: It currently places the watermark centered, near the bottom of your pictures. The chunk containing the watermark is indeed re-encoded (lossy) but it's not humanely visible.
:: Because the whole picture is not re-encoded, it is blazing fast. Bonus: it adds Exif/XMP/IPTC Copyright tags.
:: 
:: How to use this batch?
:: * test it by dropping a jpeg over it a see the magic
:: * you can also drop a folder over it
:: * the best way: place a shortcut to it in your sendTo folder!
:: 
:: * Requisites:
:: - jpegtran https://jpegclub.org/jpegtran/                            Jpeg lossless operations
:: - iMagick  https://www.imagemagick.org/script/download.php#windows   Portable Win64 static at 16 bits-per-pixel component.
:: - exiftool https://exiftool.org/                                     ExifTool by Phil Harvey
::
:: * TODO:
:: * [ ] BUG: does not work for portrait
:: * [ ] BUG: does not work for pictures smaler then 2048
:: * [ ] find a way to shift from bottom that's not a fixed amount of pixels
:: * [ ] offer an easy way to place the watermark where user wants it
:: * [ ] use Exif template for copyright: https://blog.laurencebichon.com/en/metadata-copyright-example-for-a-freelance-photographer/
:: * [ ] add more examples for Exif/XMP?IPTC tags
:: * [ ] export all custom values in a separate file/script
:: * [ ] include a list of all fonts available with imagick
:: * [ ] add prechecks for all required binaries
:: * [ ] add option to overwrite original files
::
:: * revisions:
:: - 1.4.0    create and stack chunks with different values of alpha/color with a number on top and let user choose the best one
:: - 1.3.2    prompt for additional tags and alpha
:: - 1.3.1    prompt for different tagFiles
:: - 1.3.0    batch processing
:: - 1.2.0    exiv2/IPTC/XMP tags and copyright based off a text file
:: - 1.1.0    working release
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
set version=1.4.0

:: uncomment to enable DEBUG
REM set DEBUG=true
set chunkName=%~dp0\chunk.%RANDOM%
set chunkExt=png
set watermarkName=%~dp0\watermark.%RANDOM%
set watermarkExt=jpg
set watermarkStack=%~dp0\watermark.%RANDOM%-stack.jpg

:: codepage 65001 is pretty much UTF8, so you can use whichever unicode characters in your watermark
chcp 65001 >NUL

:defaults
:: 99.99% of jpeg have a 8x8 block DCT with 2x1 sample factor, but this will be extracted from the original jpeg anyway
set hsample=16
set vsample=8
set alpha2try=0.5 0.3 1
set fontColor2try="255,255,255" "0,0,0"

::::::::::::::::::::::::::::::::::::::::::::: customize your own values here :::::::::::::::::::::::::::::::::::::::::::::
:custom
:: it is critical that you provide here the path to jpegtran and imagick here
set "PATH=%PATH%;E:\wintools\PortableApps\Magick;E:\wintools\multimedia\jpegtran;E:\wintools\multimedia\exiv2-0.27.4-2019msvc64\bin"
:: watermarkText is, well, your watermark! Put you name or whatever unicode characters you like
set watermarkText=©^&ric photography
:: copyrightTag is added in the output filename before the extension: filename[copyrightTag].jpg
set copyrightTag=-ldo
:: exitTags are all the copyright.*.txt that you will be prompted to choose from, when tagging your pictures; first one is the default
set exitTags=ldo ChristmasGrinch example
:: in exifTagsFile you store the Exif/XMP?IPTC tags to add
set exifTagsFile=%~dp0\copyright.exitTag.txt
:: prompt for adding tags manually; set to false or comment it out to disable addExifTags
set addExifTagsFile=true
:: set this to false or comment it out to use the first file in the list exitTags, otherwise you will be prompted
set promptForExifTagsFile=false
:: set this to true to be prompted for additional tags to add manually
set promptForAdditionalTags=true
:: set this to true to also update the tags for the original image; after all, why would they be different?
set alsoApplyTagsForOriginal=true

:: specify a true type font here
set font=%~dp0\Romantica-RpXpW.ttf
:: watermark width and height as a percentage of your pictures
set wwidthPct=30
set wheightPct=9
:: bottomDistance is the pixel distance from the bottom of the picture, at which the watermark will sit
set bottomDistance=80
:: Gravity is the rough position of the watermark: Center, North, South, East, Northeast, etc; https://legacy.imagemagick.org/Usage/annotating/
:: it has to be centered since we want to spread over the whole chunck we replace in the picture
set wGravity=Center
:: Point_Size and wwidth really depends on the font type and the height of the watermark.
:: Play with textScale to see if it fits; the example Romantica-RpXpW.ttf provided is a bit special tho
set textScale=80

:: Scale will rescale your output files
set Scale=100
:: alpha is transparency of the watermark font
set alpha=0.5
:: let you choose alpha manually; comment or set to false to disable
set promptForAlpha=true
:: RGB fontColor; user quotes because it's MSDOS
set fontColor="255,255,255"

:: interactive choice for color and alpha; will override promptForAlpha; do not use when looping over hundreds of images...
set promptForSampleTesting=true
:: the default sample choice when prompted; will be updated with user's last choice
set sampleChoice=1
::::::::::::::::::::::::::::::::::::::::::::: customize your own values here :::::::::::::::::::::::::::::::::::::::::::::

:prechecks
call :set_colors
IF "%~1"=="" echo %r%ERROR: %~n0 takes arguments: jpeg(s) to process%END% 1>&2 & timeout /t 5 & exit /b 99
where magick >NUL 2>&1 || (echo %r%ERROR: magick.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)
where jpegtran >NUL 2>&1 || (echo %r%ERROR: jpegtran.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)
IF /I "%addExifTagsFile%"=="true" where exiv2 >NUL 2>&1 || (echo %r%ERROR: exiv2.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)

del /f /q %chunkName%.%chunkExt% %watermarkName%.%watermarkExt% 2>NUL


:::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::
:main

IF /I "%promptForSampleTesting%"=="true" set promptForAlpha=false
IF /I "%promptForAlpha%"=="true" set /P alpha=alpha? [%alpha%] 

call :isFolder %* && for %%F in ("%~1\*.jpg") DO call :loop %%F
call :isFolder %* || for %%F in (%*)          DO call :loop %%F
goto :end
:::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::


:loop
:: do not reprocess already processed files...
IF NOT DEFINED DEBUG dir "%~dpn1%copyrightTag%%~x1" >NUL 2>&1 && goto :EOF
:: do not reprocess previous outputs...
dir "%~1" | findstr /I /C:"%copyrightTag%%~x1" >NUL 2>&1 && goto :EOF

:: outputFile must have a different name then the original file, unless overwriting is your goal
set outputFile=%~dpn1%copyrightTag%%~x1
echo:
echo Processing %~nx1 ... 1>&2

call :getJpegInfo %1
call :getWSIZE
call :calculatePoint_Size

:: we need a png chunk for transparency, bro
call :extractMagick %1 %chunkName%.%chunkExt%
:: the command below does the same but extracts jpeg and there would be no transparency
REM call :extractJpegtran %1 %chunkName%.%chunkExt%

IF /I "%promptForSampleTesting%"=="true" (
  set sample=0
  for %%c in (%fontColor2try%) DO (
    for %%a in (%alpha2try%) DO (
      call set /A sample+=1
      call set fontColor.%%sample%%=%%c
      call set fontAlpha.%%sample%%=%%a
      call :genWatermarkStack %chunkName%.%chunkExt% %watermarkName%-%%sample%%.%watermarkExt% %font% %Point_Size% %%c %%a %%sample%%
    )
  )
) ELSE (
  call :genWatermark %chunkName%.%chunkExt% %watermarkName%.%watermarkExt% %font% %Point_Size% %fontColor% %fontAlpha%
)


IF /I "%promptForSampleTesting%"=="true" (
  call :stackImages %watermarkName% %watermarkExt% %sample% %watermarkName%-stack.jpg
  %watermarkName%-stack.jpg
  set /P sampleChoice=sampleChoice? [%sampleChoice%] 
)
IF /I "%promptForSampleTesting%"=="true" (
  call :genWatermark %chunkName%.%chunkExt% %watermarkName%.%watermarkExt% %font% %Point_Size% %%fontColor.%sampleChoice%%% %%fontAlpha.%sampleChoice%%%
)
call :pasteWatermark %watermarkName%.%watermarkExt% %1 %outputFile%

call :addExifTags %outputFile% %1
call :addManualTags %outputFile% %1

:: this will open the file and pause the batch until you close it
IF DEFINED DEBUG %outputFile%

echo Processing %~nx1 ... done 1>&2
goto :EOF


:getWSIZE
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

set /A wwidth   = width * wwidthPct / 100
set /A wheight  = height * wheightPct / 100
call :logDEBUG WSIZE    =%wwidth%x%wheight%

:: hsample and vsample are used to calculate the modulo of the chunk size to ensure that it contains only indivisible blocks
set /A wwidth   = wwidth - (wwidth %% hsample)
set /A wheight  = wheight - (wheight %% vsample)

set /A wleft    = (width - wwidth) / 2
set /A wtop     = (height - wheight) - %bottomDistance%
:: hsample and vsample are used to calculate the modulo of the top/left position of the chunk, making the non-re-encoding of the whole picture possible
set /A wleft    = wleft - (wleft %% hsample)
set /A wtop     = wtop - (wtop %% vsample)

call :logDEBUG WSIZE  m8=%wwidth%x%wheight%
call :logDEBUG WPOS     =%wleft%+%wtop%

set WSIZE=%wwidth%x%wheight%
set "WPOS=%wleft%+%wtop%"
goto :EOF


:getJpegInfo
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
:: https://imagemagick.org/script/identify.php
:: https://imagemagick.org/script/escape.php
:: magick identify Filename[frame #] image-format widthxheight page-widthxpage-height+x-offset+y-offset colorspace user-time elapsed-time
:: IT WORKS!!!! but you have to define the size of the layers. Both commands are equivalent:
rem FOR /F "tokens=1,2 USEBACKQ" %%a IN (`magick identify -format "%%[fx:w]x%%[fx:h] %%[jpeg:sampling-factor]" %1`) DO SET SIZE=%%a %%b
rem FOR /F "tokens=1,2 USEBACKQ" %%a IN (`magick identify -format ""%%wx%%h %[jpeg:sampling-factor]" %1`) DO SET SIZE=%%a %%b
FOR /F "tokens=1-4 USEBACKQ" %%a IN (`magick identify -format "%%[fx:w] %%[fx:h] %%[jpeg:sampling-factor] %%Q" %1`) DO set "width=%%a" & set "height=%%b" & set "sampling=%%c" & set "Quality=%%d"

set SIZE=%width%x%height%
:: output of %[jpeg:sampling-factor] will look like 2x1,1x1,1x1; we keep only the first value
for /f "tokens=1"   %%a in ("%sampling:,= %") DO set "samplingFactor=%%a"
:: sampling-factor of 2x1 means that your jpeg is made of 16x8 indivisible blocks
for /f "tokens=1,2" %%a in ("%samplingFactor:x= %") DO set /A "hsample=%%a * 8" & set /A "vsample=%%b * 8"

IF DEFINED DEBUG magick identify -ping %1 1>&2
call :logDEBUG SIZE=%SIZE%
goto :EOF


:calculatePoint_Size
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
set /A Point_Size=wheight * textScale / 100

:: https://www.imagemagick.org/Usage/resize/
set resize=
IF %Scale% NEQ 100 (
  set "resize=-resize %Scale%%%"
  set /A Point_Size=Point_Size * Scale / 100
)

goto :EOF

:extractMagick input output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF DEFINED DEBUG echo magick -define jpeg:size=%SIZE% -extract %WSIZE%+%WPOS% %1 %2
magick -define jpeg:size=%SIZE% -extract %WSIZE%+%WPOS% %1 %2
goto :EOF

:genWatermark input output %font% %Point_Size% "%fontColor%" %fontAlpha%
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

set JPEG_OPTIONS=-sampling-factor %samplingFactor% -quality %Quality%
set input=%1
set output=%2
set font=%3
set Point_Size=%4
set fontColor=%~5
set fontAlpha=%6

IF DEFINED DEBUG echo magick convert -size %WSIZE% xc:none %OPTIONS% %1 ^
%resize% ^
-gravity %wGravity% ( -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -strokewidth 7 -annotate +0+0 "%watermarkText%" ) ^
-composite -gravity %wGravity% -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -stroke none      -annotate +0+0 "%watermarkText%" ^
%JPEG_OPTIONS% ^
%2

magick convert -size %WSIZE% xc:none %OPTIONS% %1 ^
%resize% ^
-gravity %wGravity% ( -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -strokewidth 7 -annotate +0+0 "%watermarkText%" ) ^
-composite -gravity %wGravity% -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -stroke none      -annotate +0+0 "%watermarkText%" ^
%JPEG_OPTIONS% ^
%2
goto :EOF

:genWatermarkStack input output %font% %Point_Size% "%fontColor%" %fontAlpha% num
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

set JPEG_OPTIONS=-sampling-factor %samplingFactor% -quality %Quality%
set input=%1
set output=%2
set font=%3
set Point_Size=%4
set fontColor=%~5
set fontAlpha=%6
set num=%7

IF DEFINED DEBUG echo magick convert -size %WSIZE% xc:none %OPTIONS% %1 ^
%resize% ^
-gravity %wGravity% ( -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -strokewidth 7 -annotate +0+0 "%watermarkText%" ) ^
-composite -gravity %wGravity% -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -stroke none     -annotate +0+0 "%watermarkText%" ^
( -gravity southeast  -font arial  -pointsize %Point_Size% -fill green1                -annotate +0+0 "%num%" ) ^
%JPEG_OPTIONS% %2

magick convert -size %WSIZE% xc:none %OPTIONS% %1 ^
%resize% ^
-gravity %wGravity% ( -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -strokewidth 7 -annotate +0+0 "%watermarkText%" ) ^
-composite -gravity %wGravity% -font %font% -pointsize %Point_Size% -fill rgba(%fontColor%,%fontAlpha%) -stroke none     -annotate +0+0 "%watermarkText%" ^
( -gravity southeast  -font arial  -pointsize %Point_Size% -fill green1                -annotate +0+0 "%num%" ) ^
%JPEG_OPTIONS% %2

goto :EOF

:extractJpegtran input output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
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
REM jpegtran -crop %WSIZE%+%WPOS% DZ6_6045.JPG %~dp0\chunk.jpg
IF DEFINED DEBUG echo jpegtran -copy all -crop %WSIZE%+%WPOS% -optimize %1 %2
jpegtran -copy all -crop %WSIZE%+%WPOS% -optimize %1 %2

goto :EOF

:pasteWatermark watermark input output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF DEFINED DEBUG echo jpegtran -copy all -drop +%WPOS% %1 -optimize %2 %3
jpegtran -copy all -drop +%WPOS% %1 -optimize %2 %3
goto :EOF


:stackImages inputName inputExt num output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

set stacks=
for /L %%n in (1,1,%3) DO call set stacks=%%stacks%% %1-%%n.%2
IF DEFINED DEBUG echo magick convert %stacks% -gravity center -append %4
magick convert %stacks% -gravity center -append %4
goto :EOF


:addExifTags output input
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF NOT "%addExifTagsFile%"=="true" exit /b 0

for /f "tokens=1" %%a in ("%exitTags%") DO set exifTagDefault=%%a
IF "%promptForExifTagsFile%"=="true" (
  echo:
  echo               %exitTags%
  set /P exifTagDefault=exifTagFile? [%exifTagDefault%] 
)

:: now get the actual filename
call set exifTagsFileToUse=%%exifTagsFile:exitTag=%exifTagDefault%%%

IF EXIST %exifTagsFileToUse% (
  IF DEFINED DEBUG echo exiv2 -m %exifTagsFileToUse% %1
  exiv2 -m %exifTagsFileToUse% %1
  IF DEFINED DEBUG exiv2 -pi %1
  
  IF /I NOT "%alsoApplyTagsForOriginal%"=="true" goto :EOF
  IF DEFINED DEBUG echo exiv2 -m %exifTagsFileToUse% %2
  exiv2 -m %exifTagsFileToUse% %2
)
goto :EOF

:addManualTags output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF NOT "%promptForAdditionalTags%"=="true" exit /b 0

echo:
exiv2 -px %1 | findstr subject
echo       REPLACE all tags, enter tags separated by comma:
set /P tags=tags? [%tags%] 

:: exiv2 has a bug with XMP: 'add' will REPLACE tags, 'set' will ADD tags to the list
IF DEFINED tags (
  IF DEFINED DEBUG echo exiv2 -M"add Xmp.dc.subject XmpBag %tags%" %1
  exiv2 -M"add Xmp.dc.subject XmpBag %tags%" %1
  IF DEFINED DEBUG exiv2 -px %1 | findstr subject

  IF /I NOT "%alsoApplyTagsForOriginal%"=="true" goto :EOF
  IF DEFINED DEBUG echo exiv2 -M"add Xmp.dc.subject XmpBag %tags%" %2
  exiv2 -M"add Xmp.dc.subject XmpBag %tags%" %2
)
goto :EOF


:logDEBUG
IF DEFINED DEBUG echo %m%DEBUG: %* %END% 1>&2
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

:isFolder folder
IF EXIST "%~1\*" exit /b 0
exit /b 1
goto :EOF


:end
IF NOT DEFINED DEBUG del /f /q %chunkName%.* %watermarkName%.* 2>NUL
IF DEFINED DEBUG timeout /t 5


