# ex10_netcdf_scaling

This example perturbs a NetCDF `vp` grid whose horizontal coordinates are
in meters and values are in meters per second. Input modifiers convert x and
y to kilometers and velocity to kilometers per second before the anisotropic
correlation lengths `12/7` are applied.

Panel (a) shows the source grid in meters and meters per second. Panel (b)
shows the perturbed output in kilometers and kilometers per second. This
example requires `ncgen`.

Run:

```bash
./ex10_netcdf_scaling.sh
```

The script creates `ex10_netcdf_scaling.png` and
`ex10_netcdf_scaling.pdf`.
