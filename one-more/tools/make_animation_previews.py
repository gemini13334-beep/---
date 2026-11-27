"""Encode the recorded Godot frames as compact, looping GIFs."""

from pathlib import Path
import sys

from PIL import Image

root = Path(sys.argv[1])
for name, expected in (("motion-combat", 36), ("motion-boss", 30), ("motion-vega", 36), ("motion-hud", 33), ("motion-gait", 30)):
    paths = sorted((root / name).glob("*.png"))
    if len(paths) != expected:
        raise RuntimeError(f"Expected {expected} screenshots in {name}, got {len(paths)}")
    frames = []
    for path in paths:
        with Image.open(path) as source:
            frame = source.convert("RGB")
            frame.thumbnail((420, 747), Image.Resampling.LANCZOS)
            frames.append(frame)
    frames[0].save(root / f"{name}.gif", save_all=True, append_images=frames[1:], duration=67, loop=0)
