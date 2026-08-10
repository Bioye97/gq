# ex03_svi_eqtomo

This example applies GMT Earth relief to the flat SVI EQTOMO model with
`-Oa` while processing `Vp`, `Vs`, and `Density` together. The diagnostic
surface is inferred across all three parameters. If their shallowest valid
levels disagree, `topobath` reports the disagreement, uses the shallowest
shared boundary, and retains any field-specific NaN at that boundary.

The script uses the cached one-arc-minute Cascadia crop of GMT's
`@earth_relief_01m_g` dataset. If the crop is unavailable, it is downloaded
once and reduced to longitude/latitude = `-130/-116/39/52` before any 3-D
operation begins.

SVI EQTOMO uses kilometers for depth, kilometers per second for velocity,
and grams per cubic centimeter for density. The relief modifier
`+z-0.001+Zkm` converts positive-up meters to the model's positive-down
kilometer convention. All transformed models span `-T-5/2/0.1`.

The methods figure compares the original model with `-Oa -Mp`,
`-Oa -Me`, and `-Oa -Ml` using `Vs`. Maps show zero depth, and sections
follow latitude = 49 N.

The parameters figure shows the linear result for all three fields. Linear
surface minima are supplied separately:

```text
-LVp/1.5 -LVs/0.5 -LDensity/2.3
```

Water values are also defined independently as 1.5 km/s, 0 km/s, and
1.03 g/cm3 for `Vp`, `Vs`, and `Density`, respectively. Because the original
model is solid up to zero depth, wet regions use that common shallowest
boundary before the new bathymetry and water values are applied.

Run:

```bash
./ex03_svi_eqtomo.sh
```

Intermediate NetCDF models are removed when the script exits. The script
creates:

- `ex03_svi_eqtomo_methods.png` and `ex03_svi_eqtomo_methods.pdf`
- `ex03_svi_eqtomo_parameters.png` and `ex03_svi_eqtomo_parameters.pdf`
