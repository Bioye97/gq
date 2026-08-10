# ex05_cascadia_v16

This example modifies Cascadia v1.6, which includes bathymetry but omits
topography. It removes the existing bathymetry with
`-Or+b`, replaces only the bathymetry with `-Ox+b`, and adds dry-land
topography with `-Oa+t` while retaining the original ocean columns.

Cascadia v1.6 is stored in UTM Zone 10 coordinates, meters, and meters per
second. To keep memory use modest, the script resamples only the upper 5 km
onto a 10 km horizontal lattice before running `topobath`. The resulting
staging cube is about 100 kB rather than the full 121 MB source model. The
plots retain the native projection and show easting and northing in kilometers.

The script uses the cached one-arc-minute Cascadia crop of GMT's
`@earth_relief_01m_g` dataset. If unavailable, the relief is downloaded once
and reduced to longitude/latitude = `-130/-116/39/52`. Both the relief and a
GMT shoreline mask are projected to the model lattice before the 3-D
operations begin.

The staged model uses increasing positive-down depth in kilometers. The
projected relief stores positive-up elevation in meters, so
`+v-0.001+Vkm` converts its values to negative land elevation and positive
bathymetric depth before `topobath` samples it.

The bathymetry figure compares the original model, bathymetry removal, and
bathymetry replacement. The methods figure compares the original model with
`-Oa+t -Mp`, `-Oa+t -Me`, and `-Oa+t -Ml` to
`Vs = 0.5 km/s` at the new land surface. Because the existing surface and
authoritative wet/dry mask are supplied, adding topography does not require a
water value: wet columns are unchanged.

Maps show zero depth. Sections cross UTM northing = 5200 km and are limited to
the upper 2 km of the model plus the new relief above sea level.

Run:

```bash
./ex05_cascadia_v16.sh
```

Intermediate NetCDF models are removed when the script exits. The script
creates:

- `ex05_cascadia_v16_flattening.png` and
  `ex05_cascadia_v16_flattening.pdf`
- `ex05_cascadia_v16_methods.png` and `ex05_cascadia_v16_methods.pdf`
