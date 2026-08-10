# ex13_cascadia_models

This example creates two figures comparing tiling, regular cosine merging, and
aggregate cosine merging for shear-wave velocity models at 2 km depth.

The first figure uses this tiling order:

```text
SVI EQTOMO
Cascadia ANT+RF
WUS324 Cascadia
```

Its mergefile pairs both regional primaries with WUS324:

```text
SVI_EQTOMO WUS324 - cosine/cosine 0.2
Cascadia_ANT+RF WUS324 - cosine/cosine 0.2
WUS324 - - - -
```

The second figure replaces Cascadia ANT+RF with Cascadia v1.6:

```text
SVI EQTOMO
Cascadia v1.6
WUS324 Cascadia
```

```text
SVI_EQTOMO WUS324 - cosine/cosine 0.2
Cascadia_v1.6 WUS324 - cosine/cosine 0.2
WUS324 - - - -
```

In both figures, panel (a) uses first-availability tiling, panel (b) uses
regular symmetric cosine merging, and panel (c) uses aggregate merging to
normalize the weights where the primary supports overlap. All windows use
taper ratios of 0.2. Solid black lines in panel (a) outline the two primary
domains. The `-P` option fills remaining gaps in a primary from its paired
WUS324 model.

Cascadia v1.6 is converted from meters and m/s to kilometers and km/s, then
reprojected from UTM Zone 10. All input models and 2 km slices are downloaded
and cached by `prepare_vs_slices.sh` in the shared data directory.

Run:

```bash
./ex13_cascadia_models.sh
```

The script creates:

```text
ex13_cascadia_ant_rf.png
ex13_cascadia_ant_rf.pdf
ex13_cascadia_v16.png
ex13_cascadia_v16.pdf
```
