# ex13_cascadia_interpolation

This example repeats the SVI EQTOMO, Cascadia ANT+RF, and WUS324 comparison
from `ex12_cascadia_models`, but uses `-Hl -Sl+g` to fill strictly internal
holes along x-y with linear Delaunay interpolation and bridge internal gaps
along z with linear interpolation before tiling or merging.

```text
SVI_EQTOMO      WUS324 - - cosine/cosine/cosine 0.2/0.2/0.2/0.2/0/0.2
Cascadia_ANT+RF WUS324 - - cosine/cosine/cosine 0.2/0.2/0.2/0.2/0/0.2
WUS324          -      - - -                    -
```

The beginning-z taper ratio remains zero and the ending-z ratio is `0.2`.
Panel (a) shows interpolated first-availability tiling, panel (b) shows regular
cosine merging, and panel (c) shows aggregate merging. `-P` fills primary
values that remain missing after interpolation from WUS324.

Horizontal sections are shown at z = 2 km and vertical sections at latitude
= 47 N. Primary domains are outlined only in the tiling panels.

Run:

```bash
./ex13_cascadia_interpolation.sh
```

The script verifies nontrivial regular and aggregate changes in both section
directions. It creates:

- `ex13_cascadia_interpolation_horizontal.png` and
  `ex13_cascadia_interpolation_horizontal.pdf`
- `ex13_cascadia_interpolation_vertical.png` and
  `ex13_cascadia_interpolation_vertical.pdf`
