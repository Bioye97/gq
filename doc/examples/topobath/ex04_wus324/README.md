# ex04_wus324

This example modifies the WUS324 Cascadia model, which already represents an
irregular land surface and seafloor. It compares removal of topography,
bathymetry, and both before replacing the complete original surface with GMT
Earth relief.

The script uses the cached one-arc-minute Cascadia crop of GMT's
`@earth_relief_01m_g` dataset. If unavailable, the relief is downloaded once
and reduced to longitude/latitude = `-130/-116/39/52` before any 3-D
operation begins. The example itself is limited to `-126/-121/42/50` and the
native WUS324 horizontal spacing of 0.125 degrees.

WUS324 stores depth in kilometers, positive downward. The relief modifier
`+z-0.001+Zkm` converts positive-up meters to the model convention before
sampling.

The removal figure compares:

- the original topography and bathymetry
- `-Or`, which removes both
- `-Or+t`, which removes topography and retains ocean columns
- `-Or+b`, which removes bathymetry and retains land topography

The bathymetry-only output uses `-T-5/2/0.1` so its vertical axis retains
the original land material above sea level as well as the model below it.

The methods figure compares the original model with `-Ox -Mp`,
`-Ox -Me`, and `-Ox -Ml` to `Vs = 0.5 km/s` at the new land surface.
WUS324 represents its original water columns with `NaN`, which appears white
in the original cross section. Consequently, model-priority classification
(`-Cm`) cannot identify those columns from the `Vs = 0` water signature and
would classify them as land wherever finite material occurs below the
seafloor. The replacement runs deliberately retain the default GMT shoreline
classification instead. Option `-WVs/0+t0.01` then assigns `Vs = 0 km/s` to
the newly constructed water columns, which appear dark blue and demonstrate
that topobath can impose physically appropriate water values even when the
source model stores water as missing data. Maps show zero depth, and sections
follow latitude = 47 N.

Run:

```bash
./ex04_wus324.sh
```

Intermediate NetCDF models are removed when the script exits. The script
creates:

- `ex04_wus324_flattening.png` and `ex04_wus324_flattening.pdf`
- `ex04_wus324_methods.png` and `ex04_wus324_methods.pdf`
