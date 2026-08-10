# ex05_multivariable_netcdf

This example merges three variables from two multiparameter NetCDF files.
The files use different names for equivalent model parameters:

```text
model1.nc?vp,vs,den model2.nc?p,s,d 20/80 cosine 0.2/0.3
model2.nc?p,s,d - - - -
```

The source variables are listed in corresponding order. The option
`-Fvp,vs,rho` names the three output variables, giving the positional mapping

```text
vp  <- vp, p
vs  <- vs, s
rho <- den, d
```

The `-W` option adds the shared variable `weight` to the NetCDF output. It has
the long name `merging weight` and units of `1`. The script also uses `-W+o`
to create a NetCDF file containing only the coordinate and weight variables.
The asymmetric taper ratios are 0.2 at the beginning and 0.3 at the end.

Run:

```bash
./ex05_multivariable_netcdf.sh
```

The script verifies the NetCDF variables and weight metadata, then creates
`ex05_multivariable_netcdf.png` and `ex05_multivariable_netcdf.pdf`.
