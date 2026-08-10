# ex05_multivariable_netcdf

This example merges three variables from two multiparameter three-dimensional
NetCDF models. The source models use different names for equivalent fields:

```text
model1.nc?vp,vs,den model2.nc?p,s,d isotoxal_star.txt - cosine/cosine/cosine 0.3
model2.nc?p,s,d - - - - -
```

The variables in both selectors are listed in corresponding order. The option
`-Fvp,vs,rho` assigns the final output names:

```text
vp  <- vp, p
vs  <- vs, s
rho <- den, d
```

Model 1 occupies `20/80` along x, y, and z, while Model 2 and the output occupy
the full `0/100` cube. Its horizontal support is a four-pointed isotoxal star
with outer points at the `20/80` bounds, and its vertical support spans
`z = 20/80 km`. All coordinates are in kilometers. A symmetric cosine window
with a taper ratio of `0.3` merges each Model 1 field into its Model 2
equivalent. The final mergefile record tiles Model 2 outside the primary
support.

All three output fields use the same three-dimensional merging weight. The
`-W` option includes it as the fixed variable `weight`, with the long name
`merging weight` and units of `1`. The script also uses `-W+o` to create a
NetCDF file containing only the coordinates and weight.

Panels (a-d) show horizontal slices at `z = 50 km`. Panels (e-h) show vertical
sections along `y = 50 km`. The dashed orange outlines mark the isotoxal-star
and vertical supports, and the dashed black/pink line marks the location of the
vertical sections.

Run:

```bash
./ex05_multivariable_netcdf.sh
```

The script verifies the output variable names, units, weight metadata, and
weight-only output. It also reconstructs every plotted field from its primary,
secondary, and shared weight. The script creates
`ex05_multivariable_netcdf.png` and `ex05_multivariable_netcdf.pdf`.
