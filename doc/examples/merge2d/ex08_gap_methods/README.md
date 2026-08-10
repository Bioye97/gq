# ex08_gap_methods

This example compares the five interpolation methods available through the
`merge2d` `-H` option. A circular region with radius 18 grid nodes is removed
from a smooth reference field before each reconstruction. The reference and
gapped input are shown before the five results. The dashed blue circle marks
the original gap.

The mergefile contains a single input record:

```text
gapped.nc - - - -
```

The five reconstructions use:

```bash
gmt merge2d gap.merge2d -R0/100/0/100 -I1 -Hn      -Gnearest.nc
gmt merge2d gap.merge2d -R0/100/0/100 -I1 -Hl      -Glinear.nc
gmt merge2d gap.merge2d -R0/100/0/100 -I1 -Ha30/8  -Gaverage.nc
gmt merge2d gap.merge2d -R0/100/0/100 -I1 -Hs0.25  -Gspline.nc
gmt merge2d gap.merge2d -R0/100/0/100 -I1 -Hm0.25  -Gminimum_curvature.nc
```

`-Hn` uses nearest-neighbor values, while `-Hl` interpolates linearly over a
Delaunay triangulation. For `-Ha30/8`, 30 is the search radius in grid nodes
and 8 is the number of averaging sectors. The spline and minimum-curvature
methods both use a tension of 0.25. A bare `-H` is equivalent to `-Hl`.

Only nodes inside the enclosed gap are replaced. Every original data node is
preserved. Gaps connected to an input-grid edge are not filled.

Run:

```bash
./ex08_gap_methods.sh
```

The script verifies that every method fills the circular gap, preserves the
original data, and produces a distinct reconstruction. It creates
`ex08_gap_methods.png` and `ex08_gap_methods.pdf`.
