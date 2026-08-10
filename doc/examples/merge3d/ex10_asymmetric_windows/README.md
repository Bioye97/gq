# ex10_asymmetric_windows

This example separates the effects of asymmetric taper ratios from those of
using different window functions along x, y, and z. The primary value is 8,
the secondary value is 2, and the dashed orange outlines mark the primary
support within x/y/z = `15/85`.

The first configuration is symmetric in all three directions:

```text
primary secondary - - cosine/cosine/cosine 0.25
```

The next two configurations first make only the x ratios asymmetric and then
make all six directional ratios different:

```text
primary secondary - - cosine/cosine/cosine 0.05/0.40/0.25/0.25/0.25/0.25
primary secondary - - cosine/cosine/cosine 0.05/0.40/0.15/0.35/0.10/0.45
```

The six values specify the west, east, south, north, upper, and lower taper
ratios. A smaller ratio creates a narrower transition from zero to one, while
a larger ratio extends the transition farther into the support.

The final three configurations retain all six asymmetric ratios while changing
the directional function triplets:

```text
primary secondary - - trapezoid/gaussian/sine  0.05/0.40/0.15/0.35/0.10/0.45
primary secondary - - plancktaper/welch/kaiser  0.05/0.40/0.15/0.35/0.10/0.45
primary secondary - - hamming/logistic/bohman   0.05/0.40/0.15/0.35/0.10/0.45
```

The horizontal figure shows weights at z = 50 and isolates x/y behavior. The
vertical figure shows weights along y = 50 and exposes x/z behavior. The
secondary is the final fallback record in every mergefile.

Run:

```bash
./ex10_asymmetric_windows.sh
```

The script verifies baseline symmetry, the expected directional bias from the
six asymmetric ratios, distinct mixed-window results in both views, and the
exact merged relation `cube = 2 + 6 * weight`. It creates:

- `ex10_asymmetric_windows_horizontal.png` and
  `ex10_asymmetric_windows_horizontal.pdf`
- `ex10_asymmetric_windows_vertical.png` and
  `ex10_asymmetric_windows_vertical.pdf`
