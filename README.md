# JPMark

JPMark is a LOSSLESS JPEG watermarking tool.
![JPMark](https://gitea.derewonko.com/audioscavenger/JPMark/blob/master/JPMark.png?raw=true)

## How does it work?
It extracts a chunk and watermarks it using imagick, then jpegtran drops it back without the whole jpeg being re-encoded at all.
It currently places the watermark centered, near the bottom of your pictures. The chunk containing the watermark is indeed re-encoded (lossy) but it's not humanely visible.
Because the whole picture is not re-encoded, it is blazing fast. Bonus: it adds Exif/XMP/IPTC Copyright tags.

## How to use this batch?
* test it by dropping a jpeg over it a see the magic
* you can also drop a folder over it
* the best way: place a shortcut to it in your sendTo folder!

## Requisites:
- jpegtran https://jpegclub.org/jpegtran/                            Jpeg lossless operations
- iMagick  https://www.imagemagick.org/script/download.php#windows   Portable Win64 static at 16 bits-per-pixel component.
- exiftool https://exiftool.org/                                     ExifTool by Phil Harvey

## How to get it to work?
- clone this project in some random place
- download all requisites to wherever you want
- update the custom part inside
- make sure you enter the paths to all requisites in the batch properly
- Exif tags: update the custom copyright.example.txt or disable Exif tags with AddExifTags=false
- test by dragging a sample jpeg over it
- try a different font.ttf!

### TODO:
* [x] wwidthPct and wheightPct transposed for portrait
* [ ] get chunk size transposed correctly for other picture ratios then 3:2
* [x] BUG: does not work for portrait
* [x] BUG: does not work for pictures smaler then 2048
* [ ] download all requisites automatically with powershell
* [ ] find a way to shift from bottom that's not a fixed amount of pixels
* [ ] offer an easy way to place the watermark where user wants it
* [x] use Exif template for copyright: https://blog.laurencebichon.com/en/metadata-copyright-example-for-a-freelance-photographer/
* [ ] add more examples for Exif/XMP?IPTC tags
* [ ] load all custom values from a separate file/script
* [ ] include a list of all fonts available with imagick and in local folder or Windows fonts
* [x] add prechecks for all required binaries
* [ ] add option to overwrite original files
* [ ] make an app with an installer
* [ ] make money

### revisions:
- 1.4.2    wwidthPct and wheightPct transposed for portrait
- 1.4.1    bottomDistance is now a percentage and works for any size pictures
- 1.4.0    create and stack chunks with different values of alpha/color with a number on top and let user choose the best one
- 1.3.2    prompt for additional tags and alpha
- 1.3.1    prompt for different tagFiles
- 1.3.0    batch processing
- 1.2.0    exiv2/IPTC/XMP tags and copyright based off a text file
- 1.1.0    working release