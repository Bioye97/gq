# ex04_model_application

This example scales and perturbs a multiparameter three-dimensional NetCDF
model. The source axes are stored in meters and `vp` and `vs` are stored
in meters per second. Input modifiers convert all axes to kilometers and both
parameters to kilometers per second before heterogeneities are generated.

The parameters use independent realizations:

- `vp`: standard deviation 0.025 and correlation lengths `5/4/3`
- `vs`: standard deviation 0.05 and correlation lengths `3/2/1.5`

Separate Vp and Vs figures compare the original and perturbed horizontal
slices at `z = 10 km` and vertical sections at `y = 10 km`. The original
fields are converted to kilometers and kilometers per second for direct
comparison with the perturbed output. This example requires `ncgen`.

Run:

```bash
./ex04_model_application.sh
```

The script creates:

- `ex04_model_application_vp.png`
- `ex04_model_application_vp.pdf`
- `ex04_model_application_vs.png`
- `ex04_model_application_vs.pdf`
