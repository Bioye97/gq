# ex16_cascadia_polygon_supports

This example repeats the interpolated Cascadia comparison from
`ex14_cascadia_interpolation`, but neither primary uses its entire grid domain.
SVI EQTOMO uses a four-pointed isotoxal star support, while Cascadia ANT+RF
uses a triangular support. Both polygons lie entirely within their respective
primary grids and overlap one another.

The mergefile is:

```text
SVI_EQTOMO WUS324 svi_star.txt cosine/cosine 0.2
Cascadia_ANT+RF WUS324 ant_rf_triangle.txt cosine/cosine 0.2
WUS324 - - - -
```

Panel (a) shows first-availability tiling constrained to the polygon supports.
Panel (b) uses regular symmetric cosine merging, and panel (c) uses aggregate
merging where the star and triangle overlap. The support outlines are shown
only in panel (a) as dashed white lines; solid black lines show the full domains
of the primary models. Linear interpolation with `-Hl` fills internal primary
gaps before the merging operations, and `-P` fills any remaining primary gaps
from WUS324.

Run:

```bash
./ex16_cascadia_polygon_supports.sh
```

The script creates `ex16_cascadia_polygon_supports.png` and
`ex16_cascadia_polygon_supports.pdf`.
