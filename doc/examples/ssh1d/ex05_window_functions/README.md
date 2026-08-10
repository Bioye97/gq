# ex05_window_functions

This example compares six BLEND window functions for tapering a common
one-dimensional support from 20 to 80:

- boxcar
- linear
- cosine
- smoothstep
- Gaussian
- Planck taper

The non-boxcar windows use symmetric taper ratios of 0.3. Every panel uses
the same random realization. The untapered heterogeneity is plotted in gray
and the supported, tapered result is plotted in blue, while dashed lines mark
the interval boundaries. This makes the effect of each window on the
heterogeneity directly comparable.

Run:

```bash
./ex05_window_functions.sh
```

The script creates `ex05_window_functions.png` and
`ex05_window_functions.pdf`.
