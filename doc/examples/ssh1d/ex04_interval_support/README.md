# ex04_interval_support

This example restricts a one-dimensional heterogeneity realization to the
interval `20/80` with `-L`. A symmetric cosine window with taper ratios of
0.3 is applied at both ends, and `+w` includes the taper weight in the
output. The untapered and tapered fields use the same random seed so their
interiors can be compared directly.

Panels show the untapered field, the supported and tapered field, and the
corresponding taper weight. Dashed vertical lines mark the support limits.

Run:

```bash
./ex04_interval_support.sh
```

The script creates `ex04_interval_support.png` and
`ex04_interval_support.pdf`.
