# Cascadia Vs slice overview

`plot_vs_slices.sh` compares the shear-wave velocity at 2 km depth in five
public Cascadia models distributed through the CRESCENT CVM repository. It
also compares vertical sections through the models along latitude 47 N from
-5 to 60 km depth. Negative depths show elevations above sea level, making
topography represented by the models visible. The dashed line in the
horizontal figure marks this profile.

The script calls `prepare_vs_slices.sh`, which downloads each model once and
caches its exact 2 km slice and latitude 47 N section. PNW10-S is linearly
interpolated between 0 and 2.5 km, and SVI EQTOMO is interpolated between 0
and 3 km for the horizontal slice. The Cascadia v1.6 model is converted from
meters and m/s to kilometers and km/s. Its horizontal slice is reprojected
from UTM Zone 10, while its latitude 47 N profile is projected into UTM before
the model is sampled.

Run:

```bash
./plot_vs_slices.sh
```

The script creates `cascadia_vs_slices.png`, `cascadia_vs_slices.pdf`,
`cascadia_vs_vertical_slices.png`, and `cascadia_vs_vertical_slices.pdf` in
this directory.
