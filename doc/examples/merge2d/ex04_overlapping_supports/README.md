# ex04_overlapping_supports

This example compares regular and aggregate merging for two rectangular
primary supports. Primary 1 has value 8, Primary 2 has value 5, and both are
paired with the same full-domain secondary grid with value 2:

```text
primary1 secondary - cosine/cosine 0.25
primary2 secondary - cosine/cosine 0.25
secondary - - - -
```

The primary domains overlap between x coordinates 35 and 65. Without `-A`,
records are evaluated in mergefile order and the first available primary
controls the overlap. This creates a sharp transition where its support ends.

The default tiling result is also shown using the direct input order
`primary1 primary2 secondary`. It assigns the first available value at each
node without pairing or tapering the inputs.

With `-A`, `merge2d` identifies primary supports having positive overlapping
weights and normalizes their contributions. Such primaries must share the same
secondary grid. The secondary receives the remaining weight wherever the sum
of raw primary weights is below one. The final mergefile record tiles the
secondary elsewhere.

Run:

```bash
./ex04_overlapping_supports.sh
```

The script reconstructs the aggregate output from its normalized primary and
background contributions and confirms that it differs from regular merging.
The figure compares the input supports, default tiling, regular paired merge,
aggregate merge, and the difference between the two paired results. The script
creates `ex04_overlapping_supports.png` and
`ex04_overlapping_supports.pdf`.
