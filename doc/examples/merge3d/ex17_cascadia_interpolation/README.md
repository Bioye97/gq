# ex17_cascadia_interpolation

This high-taper example repeats `ex13_cascadia_interpolation`, using 0.49 on
every side except the beginning of the z axis, which remains zero.

This example repeats the SVI EQTOMO, Cascadia ANT+RF, and WUS324 comparison
from `ex16_cascadia_models`, but uses `-Hl -Sl+g` to fill strictly internal
holes along x-y with linear Delaunay interpolation and bridge internal gaps
along z with linear interpolation before tiling or merging.

```text
SVI_EQTOMO      WUS324 - - cosine/cosine/cosine 0.49/0.49/0.49/0.49/0/0.49
Cascadia_ANT+RF WUS324 - - cosine/cosine/cosine 0.49/0.49/0.49/0.49/0/0.49
WUS324          -      - - -                    -
```

The beginning-z taper ratio remains zero and the ending-z ratio is `0.49`.
Panel (a) shows interpolated first-availability tiling, panel (b) shows regular
cosine merging, and panel (c) shows aggregate merging. `-P` fills primary
values that remain missing after interpolation from WUS324.

Horizontal sections are shown at z = 2 km and vertical sections at latitude
= 47 N. Primary domains are outlined only in the tiling panels.

Run:

```bash
./ex17_cascadia_interpolation.sh
```

The script verifies nontrivial regular and aggregate changes in both section
directions. It creates:

- `ex17_cascadia_interpolation_horizontal.png` and
  `ex17_cascadia_interpolation_horizontal.pdf`
- `ex17_cascadia_interpolation_vertical.png` and
  `ex17_cascadia_interpolation_vertical.pdf`
