"""Figures for the looks: a drawn outline turned into relief.

A texture's hero piece (a gryphon, a wolf's head, a skull) is too much for
analytic distance fields. Here a part is an OUTLINE -- a handful of points a
smooth curve is run through -- filled on the supersampled grid, and turned
into a height by blurring it (a pillow: the middle of a wide part stands
higher than the middle of a narrow one, as chased metal does). Parts are laid
one over another, each from its own level, so a feather over a feather keeps
its step. materials.shade() lights the result like everything else.

    fig = Figure(256, 256)
    fig.part(curve(points), rise=6, soft=5, level=0)      # closed outline
    fig.part(blade(a, b, width), rise=3, soft=2, level=4) # a feather, a claw
    fig.facet(blade(a, b, width), rise=3, width=6, level=4)  # cut, not rolled:
                                                           # a ridge down a feather
    fig.cut(curve(points), depth=2, soft=1.5)             # an engraved hollow
    height, alpha = fig.height, fig.alpha
"""
import numpy as np
from PIL import Image, ImageDraw

import materials as M

SS = M.SS


def curve(points, closed=True, steps=14):
    """A Catmull-Rom curve through `points` (texture pixels), as a polygon."""
    p = np.asarray(points, np.float64)
    n = len(p)
    out = []
    last = n if closed else n - 1
    for i in range(last):
        if closed:
            p0, p1, p2, p3 = p[(i - 1) % n], p[i], p[(i + 1) % n], p[(i + 2) % n]
        else:
            p0, p1, p2, p3 = p[max(i - 1, 0)], p[i], p[min(i + 1, n - 1)], p[min(i + 2, n - 1)]
        for s in range(steps):
            t = s / float(steps)
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    if not closed:
        out.append(p[-1])
    return [(float(a), float(b)) for a, b in out]


def blade(a, b, width, bend=0.0, taper=0.15, steps=18, belly=0.45):
    """A feather, a claw, a leaf: from `a` to its tip `b`, `width` across at
    its widest (`belly` of the way along), bowed sideways by `bend` (texels at
    the middle), its root `taper` of the width."""
    a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
    d = b - a
    length = float(np.hypot(*d))
    u = d / max(length, 1e-6)
    nrm = np.array((-u[1], u[0]))
    left, right = [], []
    for i in range(steps + 1):
        t = i / float(steps)
        mid = a + d * t + nrm * bend * np.sin(np.pi * t)
        if t < belly:
            w = taper + (1 - taper) * np.sin(0.5 * np.pi * t / belly)
        else:
            w = np.cos(0.5 * np.pi * (t - belly) / (1 - belly)) ** 0.8
        w = 0.5 * width * w
        left.append(tuple(mid + nrm * w))
        right.append(tuple(mid - nrm * w))
    return left + right[::-1]


def mask(poly, w, h):
    """The polygon filled on the supersampled grid, 0..1."""
    im = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(im).polygon([(x * SS, y * SS) for x, y in poly], fill=255)
    return np.asarray(im, np.float32) / 255.0


class Figure(object):
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.height = np.zeros((h * SS, w * SS), np.float32)
        self.alpha = np.zeros((h * SS, w * SS), np.float32)

    def part(self, poly, rise, soft, level=0.0, clip=None, crisp=0.6):
        """Lay a part: `rise` texels of relief at its fullest, its edge rolled
        over `soft` texels, standing on `level`. `clip` keeps it inside
        another mask. Returns its mask."""
        m = mask(poly, self.w, self.h)
        if clip is not None:
            m = m * clip
        b = M.blur(m, soft * SS)
        dome = np.clip((b - 0.5) * 2.0, 0, 1) ** crisp
        # The roll carries on a little outside the half line, so the edge has
        # a wall rather than a cliff.
        wall = np.clip(b * 2.0, 0, 1)
        part = (level + rise * (0.25 * wall + 0.75 * dome)) * m
        self.height = np.where(m > 0.5, np.maximum(self.height * (1 - m) + part * m, part), self.height)
        self.alpha = np.maximum(self.alpha, m)
        return m

    def facet(self, poly, rise, width, level=0.0, clip=None, power=1.0, soft=0.6):
        """Lay a part cut rather than rolled: its surface climbs from its
        edge at a steady slope for `width` texels and is flat beyond, so a
        narrow part (a feather, a claw) comes to a ridge along its middle and
        a wide one is a bevelled plate. `power` under 1 rounds the slope's
        shoulder. The distance is the true one (scipy), softened by `soft`
        texels so the ridge is not a razor. Returns its mask."""
        from scipy.ndimage import distance_transform_edt
        m = mask(poly, self.w, self.h)
        if clip is not None:
            m = m * clip
        inside = m > 0.5
        d = distance_transform_edt(inside).astype(np.float32) / SS
        t = np.clip(d / max(width, 1e-6), 0, 1) ** power
        part = M.blur((level + rise * t) * inside, soft * SS)
        part = np.where(inside, np.maximum(part, level * 0.98), 0)
        self.height = np.where(inside, np.maximum(self.height * (1 - m) + part * m, part), self.height)
        self.alpha = np.maximum(self.alpha, m)
        return m

    def cut(self, poly, depth, soft):
        """An engraved hollow."""
        m = M.blur(mask(poly, self.w, self.h), soft * SS)
        self.height = self.height - depth * m
        return m

    def line(self, points, width, depth, soft=None):
        """An engraved line along an open curve."""
        im = Image.new("L", (self.w * SS, self.h * SS), 0)
        ImageDraw.Draw(im).line([(x * SS, y * SS) for x, y in points], fill=255, width=max(1, int(width * SS)), joint="curve")
        m = M.blur(np.asarray(im, np.float32) / 255.0, (soft or width * 0.5) * SS)
        self.height = self.height - depth * m
        return m
