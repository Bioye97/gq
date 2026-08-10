# ex07_multiple_parameters

This example applies independent, field-specific heterogeneities to `vp`,
`vs`, and `rho` in a text model. Shared defaults are overridden by
parameter name, and `-Q73+i` gives each parameter an independent
realization.

The parameter settings are:

- `vp`: standard deviation 0.025 and correlation length 12
- `vs`: standard deviation 0.05 and correlation length 6
- `rho`: standard deviation 0.015 and correlation length 3

The three panels plot the resulting relative perturbations as percentages.

Run:

```bash
./ex07_multiple_parameters.sh
```

The script creates `ex07_multiple_parameters.png` and
`ex07_multiple_parameters.pdf`.
