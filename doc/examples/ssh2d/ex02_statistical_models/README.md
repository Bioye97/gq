# ex02_statistical_models

This example compares horizontal realizations from the von Karman, Gaussian,
exponential, and white-noise statistical models. All four fields use the same
domain, spacing, standard deviation of 0.05, and seed 24. The correlated
models use a correlation length of 8; the von Karman field uses a Hurst
exponent of 0.15.

A common color scale makes the amplitudes and spatial textures directly
comparable.

Run:

```bash
./ex02_statistical_models.sh
```

The script creates `ex02_statistical_models.png` and
`ex02_statistical_models.pdf`.
