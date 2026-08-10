# ex02_pnw10_s

This example applies GMT Earth relief to the flat PNW10-S shear-wave
velocity model using the three `topobath` construction methods. Unlike the
ANT+RF model in the previous example, PNW10-S begins at zero elevation and
does not need to be flattened first.

The shared Earth relief grid is a one-arc-minute crop of GMT's
`@earth_relief_01m_g` dataset over longitude/latitude =
`-130/-116/39/52`. The script creates and caches this 1 MB regional grid if
it is unavailable. Every `topobath` operation then uses the local file.

PNW10-S stores depth in kilometers, positive downward. The relief grid stores
elevation in meters, positive upward, so `+z-0.001+Zkm` converts the relief to
the model convention before sampling. The transformed models use
`-T-5/2/0.1`, from 5 km elevation to 2 km depth at 0.1 km spacing.

The methods figure compares:

- the original flat model resampled onto the requested output lattice
- `-Oa -Mp`: pull-up/push-down addition
- `-Oa -Me`: constant one-dimensional addition
- `-Oa -Ml -LVs/0.5`: linear addition to 0.5 km/s at the land surface

The top row shows Vs at zero depth. The bottom row shows latitude = 47 N
sections through the uppermost model. Dashed lines on the maps mark the
section location. The original section has a flat surface at zero, while the
other sections show the applied relief with solid lines. In wet regions, the
flat model's common shallowest boundary is retained and `-WVs/0` defines the
new water column above the seafloor.

Run:

```bash
./ex02_pnw10_s.sh
```

Intermediate NetCDF models are removed when the script exits. The script
creates:

- `ex02_pnw10_s.png`
- `ex02_pnw10_s.pdf`
