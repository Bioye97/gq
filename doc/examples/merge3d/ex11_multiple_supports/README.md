# ex11_multiple_supports

This example compares regular and aggregate merging across six overlapping
three-dimensional supports. The horizontal domains match the corresponding
`merge2d` example, while different z intervals create additional overlap
boundaries in depth. All six supports cross z = 50 and y = 50 so they appear in
both plotted sections.

The primary values are 9, 7, 5, 8, 6, and 4. Every primary is paired with the
same full-volume secondary, which has value 1:

```text
primary1 secondary - - cosine/cosine/cosine 0.30
primary2 secondary - - cosine/cosine/cosine 0.30
primary3 secondary - - cosine/cosine/cosine 0.30
primary4 secondary - - cosine/cosine/cosine 0.30
primary5 secondary - - cosine/cosine/cosine 0.30
primary6 secondary - - cosine/cosine/cosine 0.30
secondary - - - - -
```

Regular merging evaluates these records in order, so the first available
primary controls an overlap. With `-A`, all positive primary weights at a node
are normalized together because the primaries share the same secondary pair.
This smooths internal boundaries caused by mergefile ordering. The final record
tiles the secondary outside every primary support.

The horizontal figure compares the methods at z = 50. The vertical figure
compares them along y = 50. Dashed support outlines and section-location lines
connect the geometries shown by the two figures.

Run:

```bash
./ex11_multiple_supports.sh
```

The script reconstructs the aggregate result from all six primary weights and
the remaining secondary weight in both views. It also verifies that aggregate
and regular merging differ only where at least two primary supports overlap and
that the secondary fills the background. It creates:

- `ex11_multiple_supports_horizontal.png` and
  `ex11_multiple_supports_horizontal.pdf`
- `ex11_multiple_supports_vertical.png` and
  `ex11_multiple_supports_vertical.pdf`
