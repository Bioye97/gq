# ex05_multivariable_netcdf

This example merges three variables from two multiparameter NetCDF grids.
The files use different names for equivalent model parameters:

```text
model1.nc?vp,vs,den model2.nc?p,s,d isotoxal_star.txt cosine/cosine 0.3
model2.nc?p,s,d - - - -
```

The source variables are listed in corresponding order. The option
`-Fvp,vs,rho` assigns the final output names:

```text
vp  <- vp, p
vs  <- vs, s
rho <- den, d
```

All three fields use the same merging weight and symmetric taper ratio of
`0.3`. Their support is a four-pointed isotoxal star centered at `(50, 50)`,
with its outer points at the `20/80` bounds. The secondary grid is listed again
as the final record to tile the rest of the output domain.

The `-W` option adds the fixed variable `weight` to the multiparameter output.
It has the long name `merging weight` and units of `1`. The script also uses
`-W+o` to create a NetCDF file containing only the coordinates and weight.

Run:

```bash
./ex05_multivariable_netcdf.sh
```

The script verifies the output variables, weight metadata, and weight-only
result, then creates `ex05_multivariable_netcdf.png` and
`ex05_multivariable_netcdf.pdf`.
