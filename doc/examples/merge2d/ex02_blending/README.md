# ex02_blending

This example blends a primary grid into a secondary grid using a two-dimensional
cosine taper. The primary covers `-R20/80/20/80`, while the secondary and output
cover `-R0/100/0/100`. The mergefile contains:

```text
primary secondary - cosine/cosine 0.25
secondary - - - -
```

The omitted polygon makes the primary grid domain its support. A taper ratio of
0.25 produces 15-unit taper widths along all four sides and a full-weight region
within `-R35/65/35/65`. The secondary paired on the first record is used only
inside the primary domain. The second record tiles the secondary into the rest
of the output domain. In the weight panel, the orange and blue outlines mark the
support boundary and full-weight region, respectively.

The `-W` option adds the merging weight to the output NetCDF file. Within the
primary support, `merge2d` computes

```text
merged = weight * primary + (1 - weight) * secondary
```

Run:

```bash
./ex02_blending.sh
```

The script checks the weight range and weighted combination, then creates
`ex02_blending.png` and `ex02_blending.pdf`.
