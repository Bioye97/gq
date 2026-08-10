# ex01_ant_rf

This example applies the USGS Global Hybrid Vs30 Mosaic to the Cascadia
ANT+RF model. The model already follows topography, so the Ely transition
begins at the highest model node containing Vs in each dry column. Oceanic
columns are excluded with GMT's GSHHG classification.

Five native layers spanning depths from -3 to 1 km are staged in their native
increasing, positive-down order and interpolated to 50 m vertical spacing.
The depth coordinate is converted from kilometers to meters with `+z1000`,
and `-U1000` performs the Ely equations in meters per second while retaining
Vs in kilometers per second. Plot-only section grids are flipped to the
corresponding positive-up elevation range from -1 to 3 km; the model cubes are
not reordered.

The figure compares Vs30, the original and modified surface Vs, and sections
along 47 N. Values below the documented 98 m/s lower limit of the USGS mosaic
are treated as missing.

Run:

```bash
./ex01_ant_rf.sh
```

The script creates:

- `ex01_ant_rf.png`
- `ex01_ant_rf.pdf`
