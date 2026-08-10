# ex03_interpolation

This example resamples one irregularly spaced text series onto the regular
axis `-T0/10/0.05`. It compares all interpolation methods available through
the `-S` option:

```text
-Sa       Akima spline
-Sc       Cubic spline
-Se       Step-up
-Sl       Linear interpolation
-Sn       Nearest point
-Ss0.5    Smoothing spline with a fit parameter of 0.5
```

Linear interpolation is the default when `-S` is omitted. The script verifies
that the default output is identical to the result from explicit `-Sl`.

Run:

```bash
./ex03_interpolation.sh
```

The script creates `ex03_interpolation.png` and `ex03_interpolation.pdf`.
