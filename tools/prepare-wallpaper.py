#!/usr/bin/env python3
import argparse
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("Pillow is required: python3 -m pip install Pillow") from exc

SIZES = [(320, 216), (480, 360), (800, 480)]


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    src_w, src_h = image.size
    scale = max(target_w / src_w, target_h / src_h)
    resized = image.resize((round(src_w * scale), round(src_h * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h)).convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare DockOS wallpaper PNG assets for Tom's Peripherals GPU.")
    parser.add_argument("image", help="Source photo path")
    parser.add_argument("--out", default="assets", help="Output assets directory")
    args = parser.parse_args()

    source = Path(args.image).expanduser().resolve()
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    image = Image.open(source).convert("RGB")
    fallback = None
    for size in SIZES:
        prepared = cover_resize(image, size)
        output = out_dir / f"wallpaper-{size[0]}x{size[1]}.png"
        prepared.save(output, optimize=True)
        fallback = fallback or prepared
        print(output)

    if fallback is not None:
        fallback.save(out_dir / "wallpaper.png", optimize=True)
        print(out_dir / "wallpaper.png")


if __name__ == "__main__":
    main()
