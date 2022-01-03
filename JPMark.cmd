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
:: * [ ] BUG: 90deg LeftBottom orientation is an issue, watermark still dropped at the actual bottom i.e. the right side of the picture
:: * [ ] BUG: handle folders and pictures with spaces in their names
:: * [x] BUG: wwidthPct and wheightPct transposed still don't work for squares
:: * [x] wwidthPct and wheightPct transposed for portrait
:: * [ ] Offer an easy way to guess an ideal chink size for picture ratios different then 3:2
:: * [ ] Offer an easy way to place the watermark where you want it
:: * [x] BUG: does not work for portrait
:: * [x] BUG: does not work for pictures smaler then 2048
:: * [x] add option to overwrite original files
:: * [ ] download all requisites automatically with powershell
:: * [x] find a way to shift from bottom that's not a fixed amount of pixels
:: * [x] use Exif template for copyright: https://blog.laurencebichon.com/en/metadata-copyright-example-for-a-freelance-photographer/
:: * [ ] add more examples for Exif/XMP?IPTC tags
:: * [ ] include a list of all fonts available with imagick and in local folder or Windows fonts
:: * [x] add prechecks for all required binaries
:: * [ ] load all custom values from a separate file/script
:: * [ ] make an app with an installer
:: * [ ] make money
::
:: * revisions:
:: - 1.5.2    offers to apply manual tags to all pictures
:: - 1.5.1    bug discovered: depending on how orientation is stored, watermark may be vertical on right side of the picture
:: - 1.5.0    chunk size transpose now take care of any odd ratios! We simply base the chink size off a 3:2 ratio by calculating a fake width/height only for the chunk
:: - 1.4.4    chunk size transpose bugfix for portrait
:: - 1.4.3    added option to overwrite existing watermarked pictures
:: - 1.4.2    wwidthPct and wheightPct transposed for portrait
:: - 1.4.1    bottomDistance is now a percentage and works for any size pictures
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
set version=1.5.2

:: uncomment to enable DEBUG
REM set DEBUG=true

set chunkName=%~dp0\chunk
set chunkExt=png
set watermarkName=%~dp0\watermark
set watermarkExt=jpg

:: codepage 65001 is pretty much UTF8, so you can use whichever unicode characters in your watermark
chcp 65001 >NUL

:defaults
set alpha2try=0.5 0.3 1
set fontColor2try="255,255,255" "0,0,0"
:: watermark width and height as a percentage of a 3:2 landscape; ratios will be transposed for portrait
:: this project started with my own 24M pictures that are 6000x4000 pixels which is a 3:2 ratio = 1.5
set wwidthPct=30
set wheightPct=9
:: to account for any shaped pictures such as squares and very wide landscapes, we always base our chunk ratio off a 3:2 ratio which is 1.5
:: MSDOS cannot deal with real numbers so we simply store its value times 100 and will divide by 100 when needed
set normalRatio=150

::::::::::::::::::::::::::::::::::::::::::::: customize your own values here :::::::::::::::::::::::::::::::::::::::::::::
:custom
:: it is critical that you provide here the path to jpegtran and imagick here
set "PATH=%PATH%;E:\wintools\PortableApps\Magick;E:\wintools\multimedia\jpegtran;E:\wintools\multimedia\exiv2-0.27.4-2019msvc64\bin"

:: watermarkText is, well, your watermark! Put you name or whatever unicode characters you like
set watermarkText=©^&ric photography

:: copyrightTag is added in the output filename before the extension: filename[copyrightTag].jpg
set copyrightTag=-ldo
:: exitTagsFilename are all the copyright.*.txt that you will be prompted to choose from, when tagging your pictures; first one is the default
set exitTagsFilename=ldo ChristmasGrinch example
:: in exifTagsFile you store the Exif/XMP?IPTC tags to add; 'exitTag' will be replaced by the first value in exitTagsFilename or user choice if promptForExifTagsFile=true
set exifTagsFile=%~dp0\copyright.exitTag.txt
:: prompt for adding tags manually; set to false or comment it out to disable addExifTags
set addExifTagsFile=true
:: set this to true to also update the tags for the original image; after all, why would they be different?
set alsoApplyTagsForOriginal=true
:: set overwrite=true to overwite existing watermarked pictures
set overwrite=true

:: specify a true type font here
set font=%~dp0\Romantica-RpXpW.ttf
:: watermark width and height as a percentage of your pictures
set wwidthPct=30
set wheightPct=9
:: bottomDistancePct is the percentage distance from the bottom of the picture, at which the watermark will sit
set bottomDistancePct=2
:: Gravity is the rough position of the watermark: Center, North, South, East, Northeast, etc; https://legacy.imagemagick.org/Usage/annotating/
:: it has to be centered since we want to spread over the whole chunck we replace in the picture
set wGravity=Center
:: Point_Size and wwidth really depends on the font type and the height of the watermark.
:: Play with textScale to see if it fits; the example Romantica-RpXpW.ttf provided is a bit special tho
set textScale=80

:: Scale will rescale your output files
set Scale=100
:: fontAlpha is transparency of the watermark font
set fontAlpha=0.5
:: RGB fontColor; user quotes because it's MSDOS
set fontColor="255,255,255"

:: various prompts
:: let you choose fontAlpha manually; comment or set to false to disable
set promptForAlpha=true
:: set this to false or comment it out to use the first file in the list exitTagsFilename, otherwise you will be prompted
set promptForExifTagsFile=false
:: set this to true to be prompted for additional tags to add manually
set promptForAdditionalTags=true
:: interactive choice for fontColor and fontAlpha; will override promptForAlpha; do not use when looping over hundreds of images...
set promptForSampleTesting=false
:: the default sample choice when prompted; will be updated with user's last choice
set sampleChoice=1

::::::::::::::::::::::::::::::::::::::::::::: customize your own values here :::::::::::::::::::::::::::::::::::::::::::::

:prechecks
call :set_colors
IF "%~1"=="" echo %r%ERROR: %~n0 takes arguments: jpeg(s) to process%END% 1>&2 & timeout /t 5 & exit /b 99
where magick >NUL 2>&1 || (echo %r%ERROR: magick.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)
where jpegtran >NUL 2>&1 || (echo %r%ERROR: jpegtran.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)
IF /I "%addExifTagsFile%"=="true" where exiv2 >NUL 2>&1 || (echo %r%ERROR: exiv2.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)


:::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::
:main

IF /I "%promptForSampleTesting%"=="true" set promptForAlpha=false
IF /I "%promptForAlpha%"=="true" set /P fontAlpha=alpha? [%fontAlpha%] 

call :isFolder %* && for %%F in ("%~1\*.jpg") DO call :loop %%F
call :isFolder %* || for %%F in (%*)          DO call :loop %%F
goto :end
:::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::


:loop
:: do not reprocess already processed files unles you want it
IF /I NOT "%overwrite%"=="true" dir "%~dpn1%copyrightTag%%~x1" >NUL 2>&1 && goto :EOF
:: do not reprocess previous outputs...
dir "%~1" | findstr /I /C:"%copyrightTag%%~x1" >NUL 2>&1 && goto :EOF

:: outputFile must have a different name then the original file, unless overwriting is your goal
set outputFile=%~dpn1%copyrightTag%%~x1
set chunk=%chunkName%.%RANDOM%
set watermark=%watermarkName%.%RANDOM%
echo:
echo Processing %~nx1 ... 1>&2

call :getJpegInfo %1
call :getWSIZE
call :calculatePoint_Size

:: we need a png chunk for transparency, bro
call :extractMagick %1 %chunk%.%chunkExt%
:: the command below does the same but extracts jpeg and there would be no transparency
REM call :extractJpegtran %1 %chunk%.%chunkExt%

IF /I "%promptForSampleTesting%"=="true" (
  set sample=0
  for %%c in (%fontColor2try%) DO (
    for %%a in (%alpha2try%) DO (
      call set /A sample+=1
      call set fontColor.%%sample%%="%%~c"
      call set fontAlpha.%%sample%%=%%~a
      call :genWatermarkStack %chunk%.%chunkExt% %watermark%-%%sample%%.%watermarkExt% %font% %Point_Size% %%c %%a %%sample%%
    )
  )
) ELSE (
    call :genWatermark %chunk%.%chunkExt% %watermark%.%watermarkExt% %font% %Point_Size% %fontColor% %fontAlpha%
)


IF /I "%promptForSampleTesting%"=="true" (
  call :stackImages %watermark% %watermarkExt% %sample% %watermark%-stack.%watermarkExt%
  REM :: this should open the stack for the user to see, if the jpg pictures are associated with a viewer that is
  %watermark%-stack.%watermarkExt%
  set /P sampleChoice=sampleChoice? [%sampleChoice%] 
)
IF /I "%promptForSampleTesting%"=="true" (
  call :genWatermark %chunk%.%chunkExt% %watermark%.%watermarkExt% %font% %Point_Size% %%fontColor.%sampleChoice%%% %%fontAlpha.%sampleChoice%%%
)
call :pasteWatermark %watermark%.%watermarkExt% %1 %outputFile%

call :addExifTags %outputFile% %1
call :promptForManualTags %outputFile%
call :addManualTags %outputFile% %1

:: this will open the file and pause the batch until you close it
IF DEFINED DEBUG %outputFile%

echo Processing %~nx1 ... done 1>&2
IF NOT DEFINED DEBUG del /f /q %chunk%* %watermark%* 2>NUL
goto :EOF


:getJpegInfo
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
:: https://imagemagick.org/script/identify.php
:: https://imagemagick.org/script/escape.php
:: magick identify Filename[frame #] image-format widthxheight page-widthxpage-height+x-offset+y-offset colorspace user-time elapsed-time
:: orientation is tricky:
:: TopLeft  - 1
:: TopRight  - 2
:: BottomRight  - 3
:: BottomLeft  - 4
:: LeftTop  - 5
:: RightTop  - 6
:: RightBottom  - 7
:: LeftBottom  - 8

set orientation=
FOR /F "tokens=1-5 USEBACKQ" %%a IN (`magick identify -format "%%[fx:w] %%[fx:h] %%[jpeg:sampling-factor] %%Q %%[EXIF:orientation]" %1`) DO set "width=%%a" & set "height=%%b" & set "sampling=%%c" & set "Quality=%%d" & set "orientation=%%e"

:: covering all types of orientation is impossible, also why is there 8 and not just 4?
:: you can only rotate the camera that much, does not make any sense to me
:: 90 deg left is LeftBottom and that's the only way i take vertical pictures
:: At the moment, I see no way to correctly extract and reinsert the chunk with correct orientation; 
set SIZE=%width%x%height%

:: jpeg have 8x8 blocks DCT with a sampling factor that varies depending on compression choices; this needs to be extracted
:: output of %[jpeg:sampling-factor] will look like 2x1,1x1,1x1; we keep only the first value
:: samplingFactor needs to be reused for re-encoding the jpeg chunk exactly the same or we cannot drop it inside the image
for /f "tokens=1"   %%a in ("%sampling:,= %") DO set "samplingFactor=%%a"
:: sampling-factor of 2x1 means that your jpeg is made of 16x8 indivisible blocks
for /f "tokens=1,2" %%a in ("%samplingFactor:x= %") DO set /A "hsample=%%a * 8" & set /A "vsample=%%b * 8"

:: -auto-orient will correctly report the WxH but even when used at every stage of the process, chunk goes back on the right side of the picture
IF DEFINED DEBUG magick identify -auto-orient -format "%%[fx:w] %%[fx:h] %%[jpeg:sampling-factor] %%Q %%[EXIF:orientation] \n" %1 1>&2
call :logDEBUG SIZE=%SIZE%
goto :EOF

REM 1663 1682


:getWSIZE
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

:: Note about odd sized pictures: regardless of orientation, the size of the watermark text is still respected within the chunk, because of Point_Size. However, the chunk can become is fairly large for no reason on very wide pictures, so we want to avoid that.
:: Transposition of chunk percentages for portrait: very easy! we divide the chunk ratios by the inverted picture ratio
:: Bonus: this ratioHW calculated based off a 3:2 ratio also takes care or squares, which means we now cover all cases!
IF %height% GTR %width% (
  set ratioWidth=%width%
  set /A ratioHeight=width * %normalRatio% / 100
  call set /A wwidthPct=wwidthPct * ratioHeight / width
  call set /A wheightPct=wheightPct * width / ratioHeight
) ELSE (
  set ratioHeight=%height%
  set /A ratioWidth=height * %normalRatio% / 100
)

set /A wwidth   = ratioWidth * wwidthPct / 100
set /A wheight  = ratioHeight * wheightPct / 100
call :logDEBUG WSIZE    =%wwidth%x%wheight%

:: hsample and vsample are used to calculate the modulo of the chunk size to ensure that it contains only indivisible blocks
set /A wwidth   = wwidth - (wwidth %% hsample)
set /A wheight  = wheight - (wheight %% vsample)

set /A wleft    = (width - wwidth) / 2
set /A wtop     = (height - wheight) - (bottomDistancePct * height / 100)
:: hsample and vsample are used to calculate the modulo of the top/left position of the chunk, making the non-re-encoding of the whole picture possible
set /A wleft    = wleft - (wleft %% hsample)
set /A wtop     = wtop - (wtop %% vsample)

call :logDEBUG WSIZE  m8=%wwidth%x%wheight%
call :logDEBUG WPOS     =%wleft%+%wtop%

set WSIZE=%wwidth%x%wheight%
set "WPOS=%wleft%+%wtop%"
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
IF DEFINED DEBUG echo magick convert -define jpeg:size=%SIZE% -extract %WSIZE%+%WPOS% %1 %2
magick convert -define jpeg:size=%SIZE% -extract %WSIZE%+%WPOS% %1 %2
goto :EOF

:genWatermark input output %font% %Point_Size% "%fontColor%" %fontAlpha%
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

set JPEG_OPTIONS=-sampling-factor %samplingFactor% -quality %Quality%
set input=%1
set output=%2
set font=%3
set Point_Size=%4
set color=%~5
set alpha=%6

IF DEFINED DEBUG echo magick convert -size %WSIZE% xc:none %OPTIONS% %1 ^
%resize% ^
-gravity %wGravity% ( -font %font% -pointsize %Point_Size% -fill rgba(%color%,%alpha%) -strokewidth 7 -annotate +0+0 "%watermarkText%" ) ^
-composite -gravity %wGravity% -font %font% -pointsize %Point_Size% -fill rgba(%color%,%alpha%) -stroke none      -annotate +0+0 "%watermarkText%" ^
%JPEG_OPTIONS% ^
%2

magick convert -size %WSIZE% xc:none %OPTIONS% %1 ^
%resize% ^
-gravity %wGravity% ( -font %font% -pointsize %Point_Size% -fill rgba(%color%,%alpha%) -strokewidth 7 -annotate +0+0 "%watermarkText%" ) ^
-composite -gravity %wGravity% -font %font% -pointsize %Point_Size% -fill rgba(%color%,%alpha%) -stroke none      -annotate +0+0 "%watermarkText%" ^
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

for /f "tokens=1" %%a in ("%exitTagsFilename%") DO set exifTagDefault=%%a
IF "%promptForExifTagsFile%"=="true" (
  echo:
  echo               %exitTagsFilename%
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

:promptForManualTags output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF NOT "%promptForAdditionalTags%"=="true" exit /b 0
IF     "%applyCurrentManualTagsToAllImages%"=="true" exit /b 0

echo:
exiv2 -px %1 | findstr subject
echo       REPLACE all tags, enter tags separated by comma:
set /P tags=tags? [%tags%] 

set    applyCurrentManualTagsToAllImages=n
set /P applyCurrentManualTagsToAllImages=apply those tags to all other images? [N/y] 
IF /I "%applyCurrentManualTagsToAllImages%"=="y" set applyCurrentManualTagsToAllImages=true

goto :EOF


:addManualTags output original
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

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
IF NOT DEFINED DEBUG del /f /q %chunkName%* %watermarkName%* 2>NUL
IF DEFINED DEBUG pause


