# ex11_asymmetric_windows

This example separates the effects of asymmetric taper ratios from the effects
of using different window functions along x and y. Every primary has value 8,
the secondary has value 2, and the dashed orange square marks the primary
support within `-R15/85/15/85`.

The top row first uses a symmetric cosine configuration:

```text
primary secondary - cosine/cosine 0.25
```

It then changes the west and east ratios before making all four ratios
different:

```text
primary secondary - cosine/cosine 0.05/0.40/0.25/0.25
primary secondary - cosine/cosine 0.05/0.40/0.15/0.35
```

The four values specify the west, east, south, and north taper ratios. A small
ratio produces a narrow transition from zero to one, while a larger ratio
extends the transition farther into the support.

The bottom row retains `0.05/0.40/0.15/0.35` and changes the function pair:

```text
primary secondary - trapezoid/gaussian  0.05/0.40/0.15/0.35
primary secondary - plancktaper/welch   0.05/0.40/0.15/0.35
primary secondary - hamming/logistic    0.05/0.40/0.15/0.35
```

The first function operates along x and the second operates along y. The
resulting two-dimensional weight is the product of those directional windows.
The secondary is listed as a final fallback record in every mergefile.

Run:

```bash
./ex11_asymmetric_windows.sh
```

The script verifies symmetry in the baseline, the expected westward and
southward bias from the asymmetric ratios, distinct mixed-window results, and
the exact merged relation `z = 2 + 6 * weight`. It creates
`ex11_asymmetric_windows.png` and `ex11_asymmetric_windows.pdf`.
