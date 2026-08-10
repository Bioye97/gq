# ex15_cascadia_multivariable

This example performs aggregate multiparameter merges at 2 km depth and
creates two figures. Velocities are expressed in km/s and density in g/cm3.

The first figure merges Vp and Vs using this order:

```text
SVI EQTOMO
Cascadia v1.6
WUS324 Cascadia
```

Both regional primaries are paired with WUS324 and use symmetric cosine
windows with taper ratios of 0.2. The figure compares tiling and aggregate
merging for Vp and Vs.

The second figure merges Vp, Vs, and density using:

```text
SVI EQTOMO
WUS324 Cascadia
```

SVI EQTOMO is paired with WUS324 using the same cosine window. The figure
compares tiling and aggregate merging for all three parameters. With only one
regional primary in this case, aggregate mode reduces to ordinary weighted
merging because there are no overlapping primary supports to normalize.

The script uses `-Fvp,vs` and `-Fvp,vs,density` to assign the final variable
names in the multiparameter NetCDF outputs. The `-P` option fills remaining
primary gaps from the paired WUS324 fields. GDAL combines the cached 2 km
slices into the temporary multiparameter input files.

Run:

```bash
./ex15_cascadia_multivariable.sh
```

The script creates:

```text
ex15_cascadia_vp_vs.png
ex15_cascadia_vp_vs.pdf
ex15_cascadia_vp_vs_density.png
ex15_cascadia_vp_vs_density.pdf
```
