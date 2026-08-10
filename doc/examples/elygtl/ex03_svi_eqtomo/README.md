# ex03_svi_eqtomo

This example applies the USGS Vs30 model to the multiparameter SVI EQTOMO
model. Vp, Vs, and density are passed to `elygtl` together. The Ely profiles
modify both velocities, and density is updated from the final Vp with the
Nafe-Drake relation. Oceanic columns are excluded with GSHHG.

The native 3 km vertical sampling is refined to 50 m over the upper model
before the default 350 m transition is applied. `-U1000/1000` converts the
model's kilometers-per-second velocities and grams-per-cubic-centimeter
density to SI units for the empirical equations and restores the original
units in the output.

The first figure focuses on Vs and the second compares all three material
properties along 49 N.

Run:

```bash
./ex03_svi_eqtomo.sh
```

The script creates:

- `ex03_svi_eqtomo.png` and `ex03_svi_eqtomo.pdf`
- `ex03_svi_eqtomo_parameters.png` and `ex03_svi_eqtomo_parameters.pdf`
