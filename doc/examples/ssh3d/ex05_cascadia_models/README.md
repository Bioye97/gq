# ex05_cascadia_models

This example applies three-dimensional von Karman heterogeneities through the
complete 0-60 km volumes of five Cascadia `Vs` models: Cascadia ANT+RF,
PNW10-S, SVI EQTOMO, WUS324 Cascadia, and Cascadia v1.6. Each model uses a
standard deviation of 0.04, Hurst exponent 0.3, and a distinct random seed.
The geographic models use x/y/z correlation lengths of `0.5/0.3/5` in
degrees/degrees/kilometers. Cascadia v1.6 uses equivalent axis-aligned lengths
of `50000/30000/5` in meters/meters/kilometers.

Separate figures show original and perturbed maps at 2 km depth and original
and perturbed sections along latitude 47 degrees. Every figure uses the common
Cascadia horizontal extent from 130 degrees W to 116 degrees W. Dashed black
lines on the maps mark the section location, and every section extends from
0 to 60 km depth.

To avoid expanding the large Cascadia v1.6 cube to several gigabytes in
memory, the script caches a 10 km horizontal by 2 km vertical working cube.
This cache retains the complete model domain and the full 0-60 km volume.
The public input models must first be cached with the shared Cascadia data
preparation script. This example also requires `ncgen`.

Run:

```bash
./ex05_cascadia_models.sh
```

The script creates:

- `ex05_cascadia_models_original_maps.png`
- `ex05_cascadia_models_original_maps.pdf`
- `ex05_cascadia_models_perturbed_maps.png`
- `ex05_cascadia_models_perturbed_maps.pdf`
- `ex05_cascadia_models_original_sections.png`
- `ex05_cascadia_models_original_sections.pdf`
- `ex05_cascadia_models_perturbed_sections.png`
- `ex05_cascadia_models_perturbed_sections.pdf`
