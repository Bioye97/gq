# ex02_blending

This example merges a primary cube into a secondary cube using a separable
three-dimensional cosine taper. The primary occupies `20/80` along x, y, and z,
while the secondary and output occupy `0/100` along all three axes. The
mergefile contains:

```text
primary secondary - - cosine/cosine/cosine 0.25
secondary - - - - -
```

The omitted polygon and z interval make the complete primary-cube domain its
support. A taper ratio of 0.25 produces 15-unit taper widths at both ends of
each axis and a full-weight volume within `35/65` along x, y, and z. The final
record tiles the secondary into the remainder of the output domain.

Panels (a-d) are horizontal slices at `z = 50`; the dashed black/pink line marks
the location of the vertical sections. Panels (e-h) show the corresponding sections
along `y = 50`. The orange and blue outlines in the weight panels mark the
primary support and full-weight region, respectively. The z axis increases
downward in the vertical sections.

The `-W` option adds `weight` to the output NetCDF file. The example verifies
the weight range and the weighted combination

```text
merged = weight * primary + (1 - weight) * secondary
```

on the horizontal slice.

Run:

```bash
./ex02_blending.sh
```

The script creates `ex02_blending.png` and `ex02_blending.pdf`.
