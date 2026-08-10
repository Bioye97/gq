# ex03_support_and_windows

This example tapers a three-dimensional field inside a four-pointed
isotoxal-star horizontal support extruded through the interval `z = 20/80`.
It compares two window combinations with taper ratios of 0.3 along x, y,
and z:

- cosine/cosine/cosine
- Planck taper/Welch/Kaiser

The figure displays horizontal heterogeneity slices at `z = 50` and vertical
heterogeneity slices at `y = 50`. Both window combinations use the same random
realization. Dashed outlines mark the polygon and vertical support boundaries.

Run:

```bash
./ex03_support_and_windows.sh
```

The script creates `ex03_support_and_windows.png` and
`ex03_support_and_windows.pdf`.
