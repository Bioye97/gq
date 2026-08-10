# ex02_statistical_models

This example compares the von Karman, Gaussian, exponential, and white-noise
models in three dimensions. Every realization occupies
`-R0/80/0/80 -T0/40/1`, uses a standard deviation of 0.05 and seed 24, and
is displayed as a horizontal slice at `z = 20`. The correlated cases use a
correlation length of 7; the von Karman case uses a Hurst exponent of 0.35.

Run:

```bash
./ex02_statistical_models.sh
```

The script creates `ex02_statistical_models.png` and
`ex02_statistical_models.pdf`.
