# JPMark

JPMark is a LOSSLESS JPEG watermarking tool.

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
- update the custom copyright.ldo.txt or disable Exif tags with AddExifTags=false
- make sure you enter the paths to all requisites in the batch properly
- test by dragging a sample jpeg over it
- try a different font.ttf!

### TODO:
* [ ] offer an easy way to place the watermark where the user wants it
* [ ] use Exif template for copyright: https://blog.laurencebichon.com/en/metadata-copyright-example-for-a-freelance-photographer/
* [ ] add more examples for Exif/XMP?IPTC tags
* [ ] export all custom values in a separate file/script
* [ ] include a list of all fonts available with imagick
* [ ] add prechecks for all required binaries
* [ ] add option to overwrite original files

### revisions:
- 1.3.0    added batch processing
- 1.2.0    added exiv2 tags and copyright
- 1.1.0    working release
