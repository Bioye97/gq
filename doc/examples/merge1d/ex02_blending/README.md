# ex02_blending

This example blends a primary series spanning 10/90 into a secondary series
spanning 0/100. The primary support is 20/80, and the mergefile selects a
cosine window with taper ratios of 0.25 at both ends:

```text
primary secondary 20/80 cosine 0.25/0.25
secondary - - - -
```

The paired secondary is used only inside the primary domain. The second
record tiles the secondary into coordinates where the primary is unavailable.

The `-W` option appends the merging weight to the output table. Where both
series are available, `merge1d` computes

```text
merged = weight * primary + (1 - weight) * secondary
```

Beyond the primary range, the output follows the secondary series because it
is listed as the next primary record in the mergefile.

Run:

```bash
./ex02_blending.sh
```

The script checks the weight range and weighted-component sum, then creates
`ex02_blending.png` and `ex02_blending.pdf`.
