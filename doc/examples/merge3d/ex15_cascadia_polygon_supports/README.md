# ex15_cascadia_polygon_supports

This example repeats the interpolated Cascadia comparison with horizontal
supports smaller than the primary grid domains. SVI EQTOMO uses a four-pointed
isotoxal star and Cascadia ANT+RF uses a triangle. Each polygon is extruded
through the primary model's z range.

The weighted mergefile uses:

```text
SVI_EQTOMO      WUS324 svi_star.txt       - cosine/cosine/cosine 0.2/0.2/0.2/0.2/0/0.2
Cascadia_ANT+RF WUS324 ant_triangle.txt   - cosine/cosine/cosine 0.2/0.2/0.2/0.2/0/0.2
WUS324          -      -                  - -                    -
```

The beginning-z taper is zero and the ending-z taper is `0.2`. A second
mergefile uses boxcar windows to create the hard supported tiling. All modes
use `-Sl+g` before `-P`, so internal z gaps are bridged before WUS324 fills
remaining primary values.

Horizontal sections are shown at z = 2 km. Vertical sections use latitude =
48 N so both polygons cross the profile. Solid black outlines show the full
primary domains only in the tiling panels, and dashed white outlines show the
polygon supports and their vertical extrusions.

Run:

```bash
./ex15_cascadia_polygon_supports.sh
```

The script verifies that regular merging changes supported tiling and that
aggregate normalization changes regular merging in both views. It creates:

- `ex15_cascadia_polygon_supports_horizontal.png` and
  `ex15_cascadia_polygon_supports_horizontal.pdf`
- `ex15_cascadia_polygon_supports_vertical.png` and
  `ex15_cascadia_polygon_supports_vertical.pdf`
