# DockOS Assets

Default visual release assets live here.

- Wallpaper assets are resized JPEG versions of the provided Pexels image.
- App icons are generated from Google Material Icons.

Use:

```bash
python3 tools/prepare-wallpaper.py /path/to/photo.jpg --out assets
```

Generated wallpaper files are optional for the installer, but DockOS will use them when present:

- `wallpaper-320x216.jpg`
- `wallpaper-480x270.jpg`
- `wallpaper-480x360.jpg`
- `wallpaper-640x360.jpg`
- `wallpaper-800x360.jpg`
- `wallpaper-800x480.jpg`
- `wallpaper-960x540.jpg`
- `wallpaper.jpg`
