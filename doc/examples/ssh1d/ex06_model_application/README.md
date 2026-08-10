# ex06_model_application

This example applies a fractional von Karman heterogeneity field to the
`vp` column of a synthetic one-dimensional velocity model. The same seed
and statistics are used to generate the standalone perturbation and the
perturbed model: standard deviation 0.04, correlation length 3, Hurst
exponent 0.3, and seed 37.

Panel (a) plots the fractional perturbation against depth. Panel (b) compares
the original and perturbed P-wave velocity profiles. Depth increases
downward.

Run:

```bash
./ex06_model_application.sh
```

The script creates `ex06_model_application.png` and
`ex06_model_application.pdf`.
