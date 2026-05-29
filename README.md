# Paste image path

Save clipboard image to a configurable path, then paste the saved file path as text.

# Usage

Make sure you have installed Alfred locally. After downloading the [workflow file](./Paste-image-to-path.alfredworkflow), double click to complete the installation.

Set your save path in the AppleScript:

```applescript
set save_dir to "~/Desktop"
```

For example:

```applescript
set save_dir to "/Users/yourname/Documents/paste_images"
```

## Hotkey

Use the shortcut key to save the clipboard image and paste its file path directly:

<kbd>cmd + option + v</kbd>

The workflow will:

1. Check whether the clipboard contains an image.
2. Save the image as a PNG file to `save_dir`.
3. Copy the saved file path to the clipboard.
4. Paste the file path into the current app.

# Permissions

Alfred needs Accessibility permission to paste the path into the current app:

```text
System Settings -> Privacy & Security -> Accessibility -> Alfred
```

# License

[MIT](./LICENSE)
