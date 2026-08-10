# ex09_multiple_parameters

This example applies independent heterogeneities to the `vp`, `vs`, and
`rho` variables of a multiparameter NetCDF grid. Parameter-specific
standard deviations and x/y correlation lengths override shared defaults:

- `vp`: 0.025 and `12/8`
- `vs`: 0.05 and `7/4`
- `rho`: 0.015 and `4/3`

The `+i` seed modifier creates independent fields. The panels show the
relative perturbation of each variable in percent. This example requires
`ncgen`.

Run:

```bash
./ex09_multiple_parameters.sh
```

The script creates `ex09_multiple_parameters.png` and
`ex09_multiple_parameters.pdf`.
