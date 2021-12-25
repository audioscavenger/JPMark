# JPMark

JPMark is a LOSSLESS JPEG watermarking tool.
![JPMark](https://gitea.derewonko.com/audioscavenger/JPMark/raw/branch/master/JPMark.png)

## Presentation
### How does it work?
`Imagick` extracts a chunk and watermarks it, then `jpegtran` drops it back at the same spot without the whole jpeg being recompressed at all.

The chunk size and position matches exaclty the nearest DCT block, based off the actual sampling factor of the picture. A 8x8 modulo is applied to make sure we match the nearest block.

The chunk containing the watermark is recompressed with the exact same quality settings and sampling factor as the original picture.

The watermark will be centered by default, near the bottom of your pictures. Actual position and size is customizable, and shoudl depend on the font you use. Some trial and error will be needed to make sure the chunk covers the watermark exactly.

Because the whole picture is NOT recompressed, it is blazing fast and you keep the original JPEG quality!

Bonus: Also adds Exif/XMP/IPTC Copyright tags with `exiv2`.

### Wait, what? LOSSLESS?
Recompression of the watermark chunk is indeed lossy, but it's not humanely visible.

### Then it's not 100% lossless, isn't that clickbait?
I do whatever I want :)

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
* [ ] Offer an easy way to guess an ideal chink size for picture ratios different then 3:2
* [ ] Offer an easy way to place the watermark where you want it
* [x] BUG: does not work for portrait
* [x] BUG: does not work for pictures smaler then 2048
* [x] add option to overwrite original files
* [ ] download all requisites automatically with powershell
* [x] find a way to shift from bottom that's not a fixed amount of pixels
* [x] use Exif template for copyright: https://blog.laurencebichon.com/en/metadata-copyright-example-for-a-freelance-photographer/
* [ ] add more examples for Exif/XMP?IPTC tags
* [ ] include a list of all fonts available with imagick and in local folder or Windows fonts
* [x] add prechecks for all required binaries
* [ ] load all custom values from a separate file/script
* [ ] make an app with an installer
* [ ] make money

### revisions:
- 1.4.3    added option to overwrite existing watermarked pictures
- 1.4.2    wwidthPct and wheightPct transposed for portrait
- 1.4.1    bottomDistance is now a percentage and works for any size pictures
- 1.4.0    create and stack chunks with different values of alpha/color with a number on top and let user choose the best one
- 1.3.2    prompt for additional tags and alpha
- 1.3.1    prompt for different tagFiles
- 1.3.0    batch processing
- 1.2.0    exiv2/IPTC/XMP tags and copyright based off a text file
- 1.1.0    working release