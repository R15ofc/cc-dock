# DockOS Assets

Put generated wallpaper PNG files here before publishing a visual release.

Use:

```bash
python3 tools/prepare-wallpaper.py /path/to/photo.jpg --out assets
```

Generated files are optional for the installer, but DockOS will use them when present:

- `wallpaper-320x216.png`
- `wallpaper-480x360.png`
- `wallpaper-800x480.png`
- `wallpaper.png`
