# ex12_cascadia_models

This example compares three-dimensional tiling, regular cosine merging, and
aggregate cosine merging for Cascadia shear-wave velocity models. It uses this
first-availability order:

```text
SVI EQTOMO
Cascadia ANT+RF
WUS324 Cascadia
```

Both regional primaries are paired with WUS324 in the mergefile:

```text
SVI_EQTOMO     WUS324 - - cosine/cosine/cosine 0.2/0.2/0.2/0.2/0/0.2
Cascadia_ANT+RF WUS324 - - cosine/cosine/cosine 0.2/0.2/0.2/0.2/0/0.2
WUS324          -      - - -                    -
```

The six ratios represent west, east, south, north, beginning-z, and ending-z
tapers. The beginning-z ratio is zero, so regional model weights are not
tapered away at the shallow boundary. The ending-z ratio remains `0.2`.
All three selectors use `+Vkm/s` to declare common target-unit metadata.

The output covers longitude/latitude = `-130/-116/39/52` and depths from 0 to
60 km. The horizontal figure shows z = 2 km and marks the latitude = 47 N vertical
section with a dashed black line. The vertical figure shows that section and
marks z = 2 km. Solid black outlines appear only on the tiling panels and mark
the two primary model domains.

Panel (a) uses first-availability tiling, panel (b) uses regular merging, and
panel (c) uses aggregate merging to normalize weights where the primary
supports overlap. The `-P` option fills remaining primary gaps from WUS324
after interpolation.

The full public NetCDF models are downloaded and cached by
`prepare_vs_slices.sh` in the shared data directory.

Run:

```bash
./ex12_cascadia_models.sh
```

The script verifies that regular merging changes tiling and that aggregate
normalization changes the regular result in both plotted sections. It creates:

- `ex12_cascadia_models_horizontal.png` and
  `ex12_cascadia_models_horizontal.pdf`
- `ex12_cascadia_models_vertical.png` and
  `ex12_cascadia_models_vertical.pdf`
