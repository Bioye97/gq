# ex05_polygon_support

This example confines a two-dimensional realization to a diamond-shaped
polygon. The supported field uses a cosine window with a taper ratio of 0.3,
and `+w` writes the taper weight alongside the heterogeneity field.

The panels show the untapered realization, the tapered realization inside the
polygon, and the taper weight. Dashed outlines mark the polygon support.

Run:

```bash
./ex05_polygon_support.sh
```

The script creates `ex05_polygon_support.png` and
`ex05_polygon_support.pdf`.
