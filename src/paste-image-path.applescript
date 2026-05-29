use framework "AppKit"
use framework "Foundation"
use scripting additions

-- Set the folder where clipboard images will be saved when the clipboard contains raw image data.
-- Change this path if you want to save images somewhere else.
set save_dir to "~/Desktop"

set image_extensions to {"png", "jpg", "jpeg", "webp", "gif", "tiff", "tif", "heic"}

-- Expand "~" manually because AppleScript does not expand it automatically.
if save_dir starts with "~/" then
    set home_dir to POSIX path of (path to home folder)
    set save_dir to home_dir & text 3 thru -1 of save_dir
end if

-- Remove trailing slash if present.
if save_dir ends with "/" then
    set save_dir to text 1 thru -2 of save_dir
end if

-- Make sure the target folder exists.
do shell script "mkdir -p " & quoted form of save_dir

-- Check whether a path points to an existing image file.
on isValidImagePath(file_path, image_extensions)
    try
        set file_exists to do shell script "if [ -f " & quoted form of file_path & " ]; then echo yes; else echo no; fi"
        if file_exists is not "yes" then return false

        set file_ext to do shell script "basename " & quoted form of file_path & " | awk -F. '{print tolower($NF)}'"
        return file_ext is in image_extensions
    on error
        return false
    end try
end isValidImagePath

-- Return the first saved file that matches the given content hash.
on findExistingHashedImage(save_dir, image_hash)
    try
        return do shell script "find " & quoted form of save_dir & " -maxdepth 1 -type f -name '*-" & image_hash & ".png' -print -quit"
    on error
        return ""
    end try
end findExistingHashedImage

-- Normalize a text or file URL path.
on normalizePath(file_path)
    set normalized_path to file_path

    if normalized_path starts with "file://" then
        set normalized_path to do shell script "python3 -c " & quoted form of "import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1].replace('file://', '', 1)))" & " " & quoted form of normalized_path
    end if

    if normalized_path starts with "~/" then
        set home_dir to POSIX path of (path to home folder)
        set normalized_path to home_dir & text 3 thru -1 of normalized_path
    end if

    return normalized_path
end normalizePath

-- 1. If clipboard is already a text path, paste it directly if it is a valid image file.
try
    set clipboard_text to the clipboard as text
    set clipboard_text to do shell script "printf %s " & quoted form of clipboard_text & " | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
    set clipboard_text to normalizePath(clipboard_text)

    if isValidImagePath(clipboard_text, image_extensions) then
        return clipboard_text
    end if
end try

-- 2. If Finder copied an image file, read the file URL from the pasteboard and return its path.
set pasteboard to current application's NSPasteboard's generalPasteboard()
set file_urls to pasteboard's readObjectsForClasses:{current application's NSURL} options:(missing value)

if file_urls is not missing value and (file_urls's |count|()) > 0 then
    set first_url to file_urls's objectAtIndex:0
    set copied_file_path to first_url's |path|() as text
    set copied_file_path to normalizePath(copied_file_path)

    if isValidImagePath(copied_file_path, image_extensions) then
        return copied_file_path
    end if
end if

-- 3. If clipboard contains raw image data, save it as a PNG file only when needed.
set clipboard_image to current application's NSImage's alloc()'s initWithPasteboard:pasteboard

if clipboard_image is missing value then
    display dialog "The clipboard does not contain an image or a valid image file path." buttons {"OK"} default button "OK" with icon caution
    return ""
end if

set tiff_data to clipboard_image's TIFFRepresentation()
set bitmap_rep to current application's NSBitmapImageRep's imageRepWithData:tiff_data
set png_data to bitmap_rep's representationUsingType:(current application's NSBitmapImageFileTypePNG) |properties|:(current application's NSDictionary's dictionary())

-- Write PNG data to a temporary file so we can calculate a stable hash before choosing the final path.
set temp_path to do shell script "mktemp /tmp/alfred-paste-image-path.XXXXXX.png"
set temp_save_result to png_data's writeToFile:temp_path atomically:true

if temp_save_result as boolean is false then
    display dialog "Failed to prepare image data." buttons {"OK"} default button "OK" with icon stop
    return ""
end if

set image_hash to do shell script "shasum -a 256 " & quoted form of temp_path & " | awk '{print $1}'"
set existing_file_path to findExistingHashedImage(save_dir, image_hash)

if existing_file_path is not "" then
    do shell script "rm -f " & quoted form of temp_path
    return existing_file_path
end if

set timestamp to do shell script "date +%Y-%m-%d-%H-%M-%S"
set file_name to "image-" & timestamp & "-" & image_hash & ".png"
set file_path to save_dir & "/" & file_name

set save_result to png_data's writeToFile:file_path atomically:true
do shell script "rm -f " & quoted form of temp_path

if save_result as boolean is false then
    display dialog "Failed to save image." buttons {"OK"} default button "OK" with icon stop
    return ""
end if

return file_path
