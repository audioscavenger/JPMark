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
:: * [ ] BUG: xmpbag tags seems to add up instead of replacing, not sure why
:: * [ ] BUG: 90deg LeftBottom orientation is an issue, watermark still dropped at the actual bottom i.e. the right side of the picture
:: * [ ] show only last 10 lines of tags history
:: * [x] BUG: handle folders and pictures with spaces in their names
:: * [x] BUG: wwidthPct and wheightPct transposed still don't work for squares
:: * [x] wwidthPct and wheightPct transposed for portrait
:: * [ ] Offer an easy way to guess an ideal chink size for picture ratios different then 3:2
:: * [ ] Offer an easy way to place the watermark where you want it
:: * [x] BUG: does not work for portrait
:: * [x] BUG: does not work for pictures smaler then 2048
:: * [x] add option to overwrite input files
:: * [ ] download all requisites automatically with powershell
:: * [x] find a way to shift from bottom that's not a fixed amount of pixels
:: * [x] use Exif template for copyright: https://blog.laurencebichon.com/en/metadata-copyright-example-for-a-freelance-photographer/
:: * [ ] add more examples for Exif/XMP?IPTC tags
:: * [ ] include a list of all fonts available with imagick and in local folder or Windows fonts
:: * [x] add prechecks for all required binaries
:: * [ ] process any picture extension
:: * [ ] load all custom values from a separate file/script
:: * [ ] make an app with an installer
:: * [ ] make money
::
:: * revisions:
:: - 1.5.18   temporary files are now named afer the input file inside the same folder
:: - 1.5.17   renames exifTag to xmpTag
:: - 1.5.16   properly set tagsA tagsR as the command to insert XMP tags is different
:: - 1.5.15   properly detect multiple files even within a single folder argument
:: - 1.5.14   now process mixed folders/files as arguments
:: - 1.5.13   now putXmpTagsHistory only add uniq lines
:: - 1.5.12   bugfix in putXmpTagsHistory where space was added at the end of tag list
:: - 1.5.11   bugfix in putXmpTagsHistory call order
:: - 1.5.10   offers to add or replace exif tags
:: - 1.5.9    renaming conventions
:: - 1.5.8    fonts moved to fonts folder
:: - 1.5.7    copyright exif files are now auto detected
:: - 1.5.6    bugfix history saved in history.ini
:: - 1.5.5    BUGFIX: handle folders and pictures with spaces in their names
:: - 1.5.4    added ersatz of tags history in history.ini
:: - 1.5.3    do not ask for applying same tags to other pictures when only one has been passed
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
set version=1.6.0

:: uncomment below to enable DEBUG lines and pauses; also temporary chuncks ans stacks won't be deleted
REM set DEBUG=true

:: codepage 65001 is pretty much UTF8, so you can use whichever unicode characters in your watermark
chcp 65001 >NUL

set tags=
set tagsA=
set tagsR=
set moreThenOneArg=

:arguments
IF NOT "%~2"=="" set moreThenOneArg=true


:defaults
set chunkExt=png
set chunkBasename=chunk
set watermarkBasename=watermark
set watermarkExt=jpg
set history="%~dpn0.history.ini"
set copyrightFilePath=%~dp0
set fontsPath=%~dp0fonts
set applyCurrentManualTagsToAllImages=false

:: all my tools are located in the same path of different drives, depending on the desktop I use. Adapt the d e s drive letters to your needs
for %%d in (d e s) DO IF EXIST %%d:\wintools\ set DDrive=%%d

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
:: It is critical that you provide here the path to jpegtran and imagick. Adapt to your needs.
:: Exiv2 is only used for tags, and can be ignored.
set magickPATH=%DDrive%:\wintools\PortableApps\Magick
set exiv2PATH=%DDrive%:\wintools\multimedia\exiv2\bin
set jpegtranPATH=%DDrive%:\wintools\multimedia\jpegtran

:: watermarkText is, well, your watermark text! Input you name or whatever unicode characters you like.
:: enclose the whole variable + text with ""
set "watermarkText=©&ric photography"

:: copyrightTag is added in the output filename before the extension: filename[copyrightTag].jpg
set copyrightTag=-ldo
:: in xmpTagsFile you store the Exif/XMP/IPTC tags to add; you can create many differnt copyright files to choose from.
set copyrightFilePath=%~dp0
:: prompt for adding tags manually; set to false or comment it out to disable insertCopyrightFile
set copyrightFileUse=true
:: set this to true to also update the copyright AND Exif tags to the input image
set copyrightAlsoToOriginal=false
:: set overwrite=true to overwite existing watermarked pictures
set overwrite=true

:: specify a true type font here
set font="%fontsPath%\Romantica-RpXpW.ttf"
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
set fontAlpha=0.3
:: RGB fontColor; user quotes because it's MSDOS
set fontColor="255,255,255"

:: various prompts
:: let you choose fontAlpha manually; comment or set to false to disable
set promptForAlpha=true
:: set this to false or comment it out to use the first file in the alphabetically detected copyrightFileNames, otherwise you will be prompted
set copyrightFilePrompt=true
:: Exif tags from input picture are always transfered. Set promptForXmpTags to true to be prompted to REPLACE those manually
set promptForXmpTags=true
:: xmpTagModifier = A for ADD tags or R for REPLACE tags; not used if promptForXmpTags=false
set xmpTagModifier=A
:: interactive choice for fontColor and fontAlpha; will override promptForAlpha; do not use when looping over hundreds of images...
set promptForSampleTesting=false
:: the default sample choice when prompted; will be updated with user's last choice
set sampleChoice=1

::::::::::::::::::::::::::::::::::::::::::::: customize your own values here :::::::::::::::::::::::::::::::::::::::::::::

:prechecks
set "PATH=%PATH%;%magickPATH%;%exiv2PATH%;%jpegtranPATH%"

call :set_colors
IF "%~1"=="" echo %r%ERROR: %~n0 takes arguments: jpeg(s) to process%END% 1>&2 & timeout /t 5 & exit /b 99
where magick >NUL 2>&1 || (echo %r%ERROR: magick.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)
where jpegtran >NUL 2>&1 || (echo %r%ERROR: jpegtran.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)
IF /I "%copyrightFileUse%"=="true" where exiv2 >NUL 2>&1 || (echo %r%ERROR: exiv2.exe not found%END% 1>&2 & timeout /t 5 & exit /b 99)


:::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::
:main

IF /I "%promptForSampleTesting%"=="true" set promptForAlpha=false
IF /I "%promptForAlpha%"=="true" set /P fontAlpha=alpha? [%fontAlpha%] 

for %%F in (%*) DO (
  call :isFolder "%%~F" && for %%f in ("%%~F\*.jpg") DO call :loop %%f
  call :isFolder "%%~F" ||                              call :loop "%%~F"
)

goto :end
:::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::


:::::::::::::::::::::::::::::::::::::::::::::
:loop
:: do not reprocess already processed files unles you want it
IF /I NOT "%overwrite%"=="true" dir "%~dpn1%copyrightTag%%~x1" >NUL 2>&1 && goto :EOF
:: do not reprocess previous outputs...
dir /b "%~1" | findstr /I /C:"%copyrightTag%%~x1" >NUL 2>&1 && goto :EOF

:: outputFile must have a different name then the input image, unless overwriting is your goal
set outputFile="%~dpn1%copyrightTag%%~x1"
set chunk="%~dpn1.%chunkBasename%.%RANDOM%.%chunkExt%"
set watermarkRand=%~dpn1.%watermarkBasename%.%RANDOM%
echo:
echo %y%Processing%END% %~nx1 ... 1>&2

call :getJpegInfo %1
call :getWSIZE
call :calculatePoint_Size

:: we need a png chunk for transparency, bro
call :extractMagick %1 %chunk%
:: the command below does the same but extracts jpeg and there would be no transparency
REM call :extractJpegtran %1 %chunk%

IF /I "%promptForSampleTesting%"=="true" (
  set sample=0
  for %%c in (%fontColor2try%) DO (
    for %%a in (%alpha2try%) DO (
      call set /A sample+=1
      call set fontColor.%%sample%%="%%~c"
      call set fontAlpha.%%sample%%=%%~a
      call :genWatermarkStack %chunk% "%watermarkRand%-%%sample%%.%watermarkExt%" %font% %Point_Size% %%c %%a %%sample%%
    )
  )
) ELSE (
    call :genWatermark %chunk% "%watermarkRand%.%watermarkExt%" %font% %Point_Size% %fontColor% %fontAlpha%
)


IF /I "%promptForSampleTesting%"=="true" (
  call :stackImages "%watermarkRand%" %watermarkExt% %sample% "%watermarkRand%-stack.%watermarkExt%"
  REM :: this should open the stack for the user to see, if the jpg pictures are associated with a viewer that is
  "%watermarkRand%-stack.%watermarkExt%"
  set /P sampleChoice=sampleChoice? [%sampleChoice%] 
)
IF /I "%promptForSampleTesting%"=="true" (
  call :genWatermark %chunk% "%watermarkRand%.%watermarkExt%" %font% %Point_Size% %%fontColor.%sampleChoice%%% %%fontAlpha.%sampleChoice%%%
)
call :pasteWatermark "%watermarkRand%.%watermarkExt%" "%~1" %outputFile%

call :insertCopyrightFile %outputFile% %1
call :promptForXmpTags %outputFile% %1
call :insertXmpTags %outputFile% %1

:: this will open the file and pause the batch until you close it
IF DEFINED DEBUG %outputFile%

echo %y%Processing%w% %~nx1 ... %g%DONE%END% 1>&2


echo TODO - delete temp files properly
echo TODO - delete temp files properly
echo TODO - delete temp files properly
echo TODO - delete temp files properly
echo TODO - delete temp files properly
pause
pause
pause
pause
pause
IF NOT DEFINED DEBUG del /f /q "%chunk%*" "%watermarkRand%*" 2>NUL
IF NOT DEFINED DEBUG del /f /q "%chunkBasename%*" "%watermarkBasename%*" 2>NUL




goto :EOF
:::::::::::::::::::::::::::::::::::::::::::::


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
FOR /F "tokens=1-5 USEBACKQ" %%a IN (`magick identify -format "%%[fx:w] %%[fx:h] %%[jpeg:sampling-factor] %%Q %%[EXIF:orientation]" %1 2^>NUL`) DO set "width=%%a" & set "height=%%b" & set "sampling=%%c" & set "Quality=%%d" & set "orientation=%%e"

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
IF DEFINED DEBUG echo jpegtran -copy all -crop %WSIZE%+%WPOS% -optimize "%~1" "%~2"
jpegtran -copy all -crop %WSIZE%+%WPOS% -optimize "%~1" "%~2"

goto :EOF

:pasteWatermark watermark input output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF DEFINED DEBUG echo jpegtran -copy all -drop +%WPOS% "%~1" -optimize "%~2" "%~3"
jpegtran -copy all -drop +%WPOS% "%~1" -optimize "%~2" "%~3"
goto :EOF


:stackImages inputName inputExt num output
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

set stacks=
for /L %%n in (1,1,%3) DO call set stacks=%%stacks%% "%~1-%%n.%~2"
IF DEFINED DEBUG echo magick convert %stacks% -gravity center -append "%~4"
magick convert %stacks% -gravity center -append "%~4"
goto :EOF


:insertCopyrightFile output input
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF NOT "%copyrightFileUse%"=="true" exit /b 0

set copyrightFileName=
:: copyrightFileNames are all the copyright.*.txt that you will be prompted to choose from, when tagging your pictures; first alphabetical one is the default.
for /f "tokens=2 delims=." %%c in ('dir /b /o-n "%copyrightFilePath%\copyright.*.txt"') DO set copyrightFileNames=%copyrightFileNames% %%c

:: exit if not copyright file is found
IF NOT DEFINED copyrightFileName exit /b 1

IF "%copyrightFilePrompt%"=="true" (
  echo:
  echo               %copyrightFileNames%
  set /P copyrightFileName=xmpTagFile? [%copyrightFileName%] 
)

:: now get the actual filename
set copyrightFileToUse="%copyrightFilePath%\copyright.%copyrightFileName%.txt"

IF EXIST %copyrightFileToUse% (
  IF DEFINED DEBUG echo exiv2 -m %copyrightFileToUse% %1
  IF DEFINED DEBUG pause
  exiv2 -m %copyrightFileToUse% %1
  IF DEFINED DEBUG exiv2 -pi %1
  
  IF /I NOT "%copyrightAlsoToOriginal%"=="true" goto :EOF
  IF DEFINED DEBUG echo exiv2 -m %copyrightFileToUse% %2
  exiv2 -m %copyrightFileToUse% %2
) ELSE (
  echo ERROR: file %copyrightFileToUse% not found
)
goto :EOF

:promptForXmpTags output input
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%
IF NOT "%promptForXmpTags%"=="true" exit /b 0
IF     "%applyCurrentManualTagsToAllImages%"=="true" exit /b 0

echo:
:: load and show manually added tags from history; will happen only once
IF NOT DEFINED tagsA IF NOT DEFINED tagsR call :getXmpTagsHistory

:: Get tags from input image into tags variable:
for /f "tokens=3*" %%a in ('exiv2 -px %1 ^| findstr subject') do set "tags=%%b"
:: Also show the tags in input image as the last line:
echo %y%  tags=%tags% %END%

:: if no history, set REPLACE tagsR = current imput file tags
IF NOT DEFINED tagsA IF NOT DEFINED tagsR set "tagsR=%tags%"

echo:
set /P xmpTagModifier=%HIGH%%r%R%END%EPLACE or %y%A%END%DD tags?     [%HIGH%%xmpTagModifier%%END%] 
:: exiv2 has what I consider a serious bug with XmpBag commands: 'add' will REPLACE tags, 'set' will ADD tags to the list; looks inverted to me
IF /I "%xmpTagModifier%"=="A" (set "xmpTagModifierCommand=set") ELSE set "xmpTagModifierCommand=add"

call set /P tags%xmpTagModifier%=tags%HIGH%%xmpTagModifier%%END% separated by comma: [%%tags%xmpTagModifier%%%] 
IF NOT DEFINED tags%xmpTagModifier% goto :EOF

call :putXmpTagsHistory "tags%xmpTagModifier%=%%tags%xmpTagModifier%%%"

:: below we assess that there was indeed more then one image to process:
IF NOT DEFINED moreThenOneArg set "moreThenOneArg=true" && goto :EOF

set /P applyCurrentManualTagsToAllImages=apply those tags to all other images? [N/y] 
IF /I "%applyCurrentManualTagsToAllImages%"=="y" set "applyCurrentManualTagsToAllImages=true"


goto :EOF


:insertXmpTags output input
IF DEFINED DEBUG echo %m%%~0 %c%%* %END%

:: exiv2 has what I consider a serious bug with XmpBag commands: 'add' will REPLACE tags, 'set' will ADD tags to the list; looks inverted to me
set tagsToInsert=
IF     DEFINED tags%xmpTagModifier% call set "tagsToInsert=%%tags%xmpTagModifier%%%"
IF NOT DEFINED tagsToInsert goto :EOF

IF DEFINED DEBUG echo exiv2 -M"%xmpTagModifierCommand% Xmp.dc.subject XmpBag %tagsToInsert%" modify %1
exiv2 -M"%xmpTagModifierCommand% Xmp.dc.subject XmpBag %tagsToInsert%" modify %1
IF DEFINED DEBUG exiv2 -px %1 | findstr subject

IF /I NOT "%copyrightAlsoToOriginal%"=="true" goto :EOF
IF DEFINED DEBUG echo exiv2 -M"%xmpTagModifierCommand% Xmp.dc.subject XmpBag %tagsToInsert%" modify %2
exiv2 -M"%xmpTagModifierCommand% Xmp.dc.subject XmpBag %tagsToInsert%" modify %2

goto :EOF


:logDEBUG
IF DEFINED DEBUG echo %m%DEBUG: %* %END% 1>&2
goto :EOF


:getXmpTagsHistory
:: history lines are in the form: tags=USA, AZ, Las Vegas, Road
IF NOT EXIST %history% exit /b 1

:: TODO: show only the last 10 lines
:: the beauty of MSDOS... escaped file names look like strings for the for loop, must remove the quotes
for /f "tokens=*" %%t in (%history:~1,-1%) do echo %HIGH%%k% %%t %END%
:: only the last line of each will be loaded into the tagsA or tagsR variables
for /f "tokens=*" %%t in (%history:~1,-1%) do set "%%t"

goto :EOF


:putXmpTagsHistory "tagsX=tags, .."
:: tags should be separated by comma+space and protected by quotes
REM for %%t in (%*) DO (call echo %%t=%%%%t%%)>>%history%
IF DEFINED DEBUG echo DEBUG: %~1^>^>%history%
IF DEFINED DEBUG pause

findstr /I /B /E /C:"%~1" %history% >NUL || echo %~1>>%history%
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
IF DEFINED DEBUG pause ELSE timeout /t 5

