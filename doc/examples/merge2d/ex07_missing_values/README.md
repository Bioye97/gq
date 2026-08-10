# ex07_missing_values

This example demonstrates missing-value handling for two-dimensional NetCDF
grids. The primary has value 8 and stores a vertical missing band as `NaN`.
The secondary has value 2 and stores a horizontal missing band as `-99999`
without declaring that sentinel in its metadata.

The mergefile is:

```text
primary secondary - cosine/cosine 0.25
secondary - - - -
```

The command supplies the secondary sentinel through GMT's common input option:

```bash
gmt merge2d missing.merge2d -R0/100/0/100 -I1 -di-99999 -W -Gmerged.nc
```

The same merge can bridge enclosed gaps with linear Delaunay interpolation:

```bash
gmt merge2d missing.merge2d -R0/100/0/100 -I1 -di-99999 -Hl -W -Gmerged_filled.nc
```

Where both inputs are available, `merge2d` uses their weighted combination.
Where only one input is available, that value is retained regardless of the
merging weight. Where both are missing, the output is `NaN`. The output uses
`NaN` consistently even though the inputs use different representations.
With `-Hl`, each internal input gap is filled before resampling and merging;
original values are retained and gaps connected to an input-grid edge remain
missing.

Run:

```bash
./ex07_missing_values.sh
```

The script checks all three missing-data cases, verifies that the filled merge
has no remaining gaps, reconstructs the unfilled output at every available
node, and creates `ex07_missing_values.png` and `ex07_missing_values.pdf`.
