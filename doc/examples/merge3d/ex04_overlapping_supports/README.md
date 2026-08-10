# ex04_overlapping_supports

This example compares first-available tiling, regular merging, and aggregate
merging for two overlapping primary cubes. Primary 1 has value 8 and occupies
`10/65`, `15/85`, and `10/80` along x, y, and z. Primary 2 has value 5 and
occupies `35/90`, `15/85`, and `20/90`. Both are paired with the same
full-domain secondary cube with value 2:

```text
primary1 secondary - - cosine/cosine/cosine 0.25
primary2 secondary - - cosine/cosine/cosine 0.25
secondary - - - - -
```

Without `-A`, mergefile records are evaluated in order and the first primary
controls their shared volume. This can create a sharp transition where that
support ends. With `-A`, `merge3d` identifies positive overlapping primary
weights and normalizes their contributions. Overlapping primaries must share
the same secondary cube. The secondary receives the remaining contribution
where the raw primary weights sum to less than one.

Panels (a-d) show the horizontal supports and output slices at `z = 50`.
Panels (e-h) show the corresponding vertical supports and sections along
`y = 50`. Blue outlines mark Primary 1, orange outlines mark Primary 2, and the
dashed black line marks the vertical-profile location.

The script independently computes both raw support weights, reconstructs the
normalized aggregate result in the horizontal and vertical views, and confirms
that aggregate and regular merging differ.

Run:

```bash
./ex04_overlapping_supports.sh
```

The script creates `ex04_overlapping_supports.png` and
`ex04_overlapping_supports.pdf`.
