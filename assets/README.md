# DockOS Assets

Default visual release assets live here.

- Boot logo assets are generated from `DockOsLogoShort.png` and installed as fixed PNG sizes.
- Wallpaper assets are exact-fit PNG versions of the Pexels release wallpaper.
- Tile app icons are installed as opaque PNGs for Tom GPU rendering.

Use:

```bash
python3 tools/prepare-wallpaper.py /path/to/photo.jpg --out assets
```

Generated wallpaper files match the supported Tom bitmap monitor walls:

- `wallpaper-160x144.png` - compact `1x2` fallback
- `wallpaper-320x216.png` - `2x3`
- `wallpaper-320x288.png` - `2x4`
- `wallpaper-480x432.png` - `3x6`
- `wallpaper-640x576.png` - `4x8`
