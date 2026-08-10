# ex08_netcdf_scaling

This example applies heterogeneity to a two-parameter NetCDF model whose
coordinate is stored in meters and velocities are stored in meters per
second. Input modifiers convert the coordinate to kilometers with
`+x0.001` and both selected parameters to kilometers per second with
`+v0.001` before the correlation length of 10 is interpreted.

Panel (a) shows the source `vp` and `vs` values in their original units.
Panel (b) shows the perturbed output in the transformed units. This example
requires `ncgen` in addition to GQ and GMT.

Run:

```bash
./ex08_netcdf_scaling.sh
```

The script creates `ex08_netcdf_scaling.png` and
`ex08_netcdf_scaling.pdf`.
