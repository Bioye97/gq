# ex11_cascadia_slices

This example adds two-dimensional von Karman heterogeneities to 2 km
shear-wave velocity slices from five Cascadia models: Cascadia ANT+RF,
PNW10-S, SVI EQTOMO, WUS324 Cascadia, and Cascadia v1.6.

Each model uses a standard deviation of 0.04, geographic correlation lengths
of `0.5/0.3`, Hurst exponent 0.3, and a distinct seed. Separate figures show
the five original and five perturbed slices on a common velocity color scale.
Both figures use the same Cascadia region and Mercator projection so the maps
retain their geographic proportions. Plain map frames, coastlines, and `2 km`
labels follow the style of the other Cascadia examples. The input slices must
first be cached with the shared Cascadia data preparation script.

Run:

```bash
./ex11_cascadia_slices.sh
```

The script creates:

- `ex11_cascadia_slices_original.png`
- `ex11_cascadia_slices_original.pdf`
- `ex11_cascadia_slices_perturbed.png`
- `ex11_cascadia_slices_perturbed.pdf`
