# ex04_wus324

This example applies the USGS Vs30 model to the topographic WUS324 Cascadia
model. Vp, Vs, and density are modified together over dry land; ocean and
other wet columns are left unchanged. The transition begins at the highest
finite Vs node in each land column.

The upper model is staged at 50 m vertical spacing. WUS324 velocities are
stored in kilometers per second, while density is stored in kilograms per
cubic meter. `+v1,1,0.001` first converts density to grams per cubic
centimeter, and `-U1000/1000` performs the Ely, Brocher, and Nafe-Drake
relations in SI units while retaining the plotting units in the output.

The first figure focuses on Vs. The second compares Vp, Vs, and density along
47 N.

Run:

```bash
./ex04_wus324.sh
```

The script creates:

- `ex04_wus324.png` and `ex04_wus324.pdf`
- `ex04_wus324_parameters.png` and `ex04_wus324_parameters.pdf`
