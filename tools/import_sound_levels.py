#!/usr/bin/env python3
"""Build the addon's quieter effect files from the original full-volume clips."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess

MEDIA = Path(__file__).resolve().parents[1] / "FrozenBubble" / "Media"


def attenuate(source):
    frames = int(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "a:0",
                 "-show_entries", "stream=duration_ts", "-of", "csv=p=0", str(source)]))
    for level in range(1, 10):
        target = MEDIA / "Effects" / str(level) / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        # Preserve the original Ogg granule count even when the decoder emits
        # a padded final block or begins with a negative timestamp.
        filters = f"volume={level/10:.1f},apad=whole_len={frames},atrim=end_sample={frames},asettb=1/sr,asetpts=N"
        subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-y", "-i", str(source),
                        "-map_metadata", "-1", "-af", filters, "-c:a", "libvorbis",
                        "-q:a", "10", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        str(target)], check=True)


if __name__ == "__main__":
    music = {"introzik", "frozen-mainzik-1p", "frozen-mainzik-2p"}
    sources = sorted(p for p in MEDIA.glob("*.ogg") if p.stem not in music)
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(attenuate, sources))
