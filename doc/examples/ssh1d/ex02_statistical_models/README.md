# ex02_statistical_models

This example compares the four statistical models available in `ssh1d`:
von Karman (`-Mv`), Gaussian (`-Mg`), exponential (`-Me`), and white
noise (`-Mw`). All realizations use the same `0/100/0.1` sampling,
standard deviation of 0.05, and random seed 24. The correlated models use a
correlation length of 6; the von Karman model additionally uses a Hurst
exponent of 0.15.

Run:

```bash
./ex02_statistical_models.sh
```

The script creates `ex02_statistical_models.png` and
`ex02_statistical_models.pdf`.
