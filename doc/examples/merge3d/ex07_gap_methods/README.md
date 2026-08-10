# ex07_gap_methods

This example extends the internal-gap reconstruction from merge2d `ex08` into
three dimensions. A spherical region with radius 18 grid units is removed from
a smooth reference volume. The complete reference and gapped model are shown
before reconstructions made with all six vertical methods available through
the merge3d `-S` option.

The reconstructions use:

```bash
gmt merge3d model.nc?gapped -R0/100/0/100 -I2 -T0/100/1 -Fvalue -Sa+g      -Gakima.nc
gmt merge3d model.nc?gapped -R0/100/0/100 -I2 -T0/100/1 -Fvalue -Sc+g      -Gcubic.nc
gmt merge3d model.nc?gapped -R0/100/0/100 -I2 -T0/100/1 -Fvalue -Se+g      -Gstep.nc
gmt merge3d model.nc?gapped -R0/100/0/100 -I2 -T0/100/1 -Fvalue -Sl+g      -Glinear.nc
gmt merge3d model.nc?gapped -R0/100/0/100 -I2 -T0/100/1 -Fvalue -Sn+g      -Gnearest.nc
gmt merge3d model.nc?gapped -R0/100/0/100 -I2 -T0/100/1 -Fvalue -Ss0.25+g -Gsmoothing.nc
```

The `+g` modifier bridges internal missing layers independently in every
vertical column. It does not extrapolate beyond the model's vertical domain.
Akima, cubic, and linear interpolation provide continuous reconstructions;
step and nearest-neighbor retain discrete behavior; and the smoothing spline
uses a fit parameter of `0.25`.

This example intentionally omits `-H`: filling each native x-y layer first
would reconstruct the spherical hole before the six vertical `-S` methods
could be compared. Horizontal `-H` methods are demonstrated by the equivalent
`merge2d` gap-method example and use the same directives in `merge3d`.

The horizontal figure shows slices at `z = 50`, while the vertical figure
shows sections along `y = 50`. The dashed blue circle marks the original
spherical gap in both central cross-sections. The dashed black line in the
horizontal panels marks the vertical-section location.

Run:

```bash
./ex07_gap_methods.sh
```

The script verifies that the unfilled model remains missing at the sphere
center, every method fills the internal gap, and every pair of methods produces
a distinct vertical reconstruction. It creates:

```text
ex07_gap_methods_horizontal.png
ex07_gap_methods_horizontal.pdf
ex07_gap_methods_vertical.png
ex07_gap_methods_vertical.pdf
```
