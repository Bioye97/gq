# ex05_cascadia_v16

This example applies the USGS Vs30 model to Vp and Vs in Cascadia v1.6. The
velocity model is Cartesian in UTM Zone 10, so the geographic Vs30 grid and a
GSHHG land mask are projected onto the model lattice before `elygtl` is run.
This is a coordinate reprojection rather than an axis scaling.

Only two native layers over the example region are read from the dense source
model. They are staged at 10 km horizontal and 50 m vertical spacing, keeping
the example's memory use small. `+v0.001,0.001` converts native meters-per-
second velocities to kilometers per second, while `-U1000` restores meters
per second internally for the Ely and Brocher equations.

The first figure focuses on Vs. The second compares Vp and Vs along a profile
at northing 5200 km. Wet columns are unchanged.

Run:

```bash
./ex05_cascadia_v16.sh
```

The script creates:

- `ex05_cascadia_v16.png` and `ex05_cascadia_v16.pdf`
- `ex05_cascadia_v16_parameters.png` and
  `ex05_cascadia_v16_parameters.pdf`
