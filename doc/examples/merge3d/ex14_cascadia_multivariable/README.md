# ex14_cascadia_multivariable

This example merges full-volume Vp, Vs, and density fields from SVI EQTOMO
and WUS324 Cascadia. The SVI model is the regional primary and WUS324 is its
full-volume secondary and final fallback.

```text
SVI_EQTOMO?Vp,Vs,Density WUS324?Vp,Vs,Density - - \
    cosine/cosine/cosine 0.2/0.2/0.2/0.2/0/0.2
WUS324?Vp,Vs,Density - - - - -
```

The beginning-z taper is zero and the ending-z taper is `0.2`. Source
modifiers standardize Vp and Vs as `km/s` and density as `g/cm3`; WUS324
density is multiplied by `0.001` to convert from `kg/m3`. `-Fvp,vs,density`
assigns the final variable names.

The horizontal and vertical figures each compare first-availability tiling
with aggregate merging for all three parameters. Horizontal sections are at
z = 2 km and vertical sections at latitude = 47 N. Dashed lines connect the
two section locations.

Run:

```bash
./ex14_cascadia_multivariable.sh
```

The script checks all output names and unit attributes and verifies that every
field changes under weighted merging in both views. It creates:

- `ex14_cascadia_multivariable_horizontal.png` and
  `ex14_cascadia_multivariable_horizontal.pdf`
- `ex14_cascadia_multivariable_vertical.png` and
  `ex14_cascadia_multivariable_vertical.pdf`
