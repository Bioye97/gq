# ex04_overlapping_supports

This example compares regular and aggregate merging for two overlapping
primary supports. Both primaries are paired with the same secondary series,
as required by `-A` where their positive support weights overlap:

```text
primary1 secondary 10/65 cosine 0.25/0.25
primary2 secondary 35/90 cosine 0.25/0.25
secondary - - - -
```

You can note how the `-A` option helps prevent sharp boundaries when tiling
primary data with overlapping supports. Compare figure panels d and e.

Without `-A`, records are evaluated in mergefile order and the first available
primary is retained throughout the overlap. With `-A`, raw primary weights
that sum to more than one are normalized by their sum. Otherwise, the
secondary receives the remaining weight. The script reconstructs the
aggregate result from these contributions, verifies that they sum to one,
and confirms that the two merging modes differ inside the overlap.

Run:

```bash
./ex04_overlapping_supports.sh
```

The script creates `ex04_overlapping_supports.png` and
`ex04_overlapping_supports.pdf`.
