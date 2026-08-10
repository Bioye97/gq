# ex01_generation

This example generates isotropic and anisotropic three-dimensional von Karman
heterogeneity fields over a `100 x 100 x 100` domain. The isotropic case
uses `-C8`; the anisotropic case uses x/y/z correlation lengths of
`20/8/3`. Both use a standard deviation of 0.05, Hurst exponent of 0.3,
and seed 42.

Horizontal slices at `z = 50` and vertical sections at `y = 50` show both
realizations on a common color scale.

Run:

```bash
./ex01_generation.sh
```

The script creates `ex01_generation.png` and `ex01_generation.pdf`.
