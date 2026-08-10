# ex03_statistical_parameters

This example isolates the effects of the principal von Karman statistical
parameters while holding the random seed fixed. The three panels compare:

- standard deviations of 0.03 and 0.10
- correlation lengths of 2 and 15
- Hurst exponents of 0.15 and 0.85

The unchanged values are a standard deviation of 0.05, correlation length of
6, and Hurst exponent of 0.35. Every field is sampled over `0/100/0.1` with
seed 81.

Run:

```bash
./ex03_statistical_parameters.sh
```

The script creates `ex03_statistical_parameters.png` and
`ex03_statistical_parameters.pdf`.
