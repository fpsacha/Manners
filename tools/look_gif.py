"""A look's animation as a GIF: one state of the prompt drawn over time.

    python tools/look_gif.py lightbringer success OUT.gif
    python tools/look_gif.py archmage owed OUT.gif --end 2 --step 0.05 --hold 50
    python tools/look_gif.py forge stranger OUT.gif --end 9 --step 0.15     # the look at rest
    python tools/look_gif.py lightbringer owed-arrival OUT.gif --box 0.10,0,0.81,0.50
    python tools/look_gif.py --all lightbringer DIR      # arrival, owed, landing, refusal, at rest

Each frame is one run of tools/render_prompt.py --at T (a run a frame: a
strip's later frames carry lights over from its earlier ones), four at a time,
cut to the panel and a margin round it, and joined at the frames' own times,
so the GIF plays at the game's speed. The renderer understates light: the
game draws an additive flash brighter than this.

--box is the cut, as fractions of the renderer's picture (left, top, right,
bottom); the default holds the panel at the default size. Give 0 for the top
when a look's light reaches above the panel.

Needs what the renderer needs: lupa, Pillow and numpy.
"""
import argparse
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDER = os.path.join(ROOT, "tools", "render_prompt.py")
# What --all draws: the name in the file, the renderer's state, the last
# moment, the step, and how long the last frame is held (ms).
ALL = (
    ("1-favour-arrives", "owed-arrival", 0.8, 0.04, 900),
    ("2-owed", "owed", 2.45, 0.07, 70),
    ("3-buff-lands", "success", 0.72, 0.03, 900),
    ("4-refused", "refused", 0.5, 0.025, 900),
    ("5-at-rest", "stranger", 9.6, 0.16, 160),
)


def gif(style, state, out, start=0.0, end=0.8, step=0.04, hold=700, box=(0.10, 0.0, 0.81, 0.50), size=None):
    times = []
    t = start
    while t <= end + 1e-9:
        times.append(round(t, 3))
        t += step
    work = tempfile.mkdtemp(prefix="manners-gif-")

    def frame(k):
        d = os.path.join(work, "f%03d" % k)
        os.makedirs(d, exist_ok=True)
        args = [sys.executable, RENDER, "--style", style, "--out", d, "--states", state, "--at", "%g" % times[k]]
        if size:
            args += ["--size", size]
        subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=ROOT)
        return os.path.join(d, state + ".png")

    with ThreadPoolExecutor(4) as pool:
        paths = list(pool.map(frame, range(len(times))))
    frames = []
    for p in paths:
        if not os.path.exists(p):
            raise SystemExit("a frame was not drawn (does the look load? does the state exist?): " + p)
        im = Image.open(p).convert("RGB")
        w, h = im.size
        frames.append(im.crop((int(w * box[0]), int(h * box[1]), int(w * box[2]), int(h * box[3]))))
    durations = [int(step * 1000)] * len(frames)
    durations[-1] = hold
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=False)
    print("  %s  %d frames, %dx%d" % (out, len(frames), frames[0].size[0], frames[0].size[1]))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--all", action="store_true", help="STYLE DIR: the five moments of a look, each a GIF in DIR")
    ap.add_argument("style")
    ap.add_argument("state", help="a state of tools/render_prompt.lua (with --all: the folder to write to)")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--start", type=float, default=0.0)
    ap.add_argument("--end", type=float, default=0.8)
    ap.add_argument("--step", type=float, default=0.04)
    ap.add_argument("--hold", type=int, default=700, help="how long the last frame stays, in ms")
    ap.add_argument("--box", default="0.10,0,0.81,0.50", help="the cut: left,top,right,bottom as fractions")
    ap.add_argument("--size", help="the renderer's --size, e.g. large or 320x58x17x40")
    args = ap.parse_args()
    box = tuple(float(v) for v in args.box.split(","))
    if args.all:
        for name, state, end, step, hold in ALL:
            gif(args.style, state, os.path.join(args.state, "%s-%s.gif" % (args.style, name)), 0.0, end, step, hold, box, args.size)
        return
    if not args.out:
        ap.error("OUT.gif is missing")
    gif(args.style, args.state, args.out, args.start, args.end, args.step, args.hold, box, args.size)


if __name__ == "__main__":
    main()
