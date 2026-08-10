# ex09_gap_limits

This example demonstrates the `+m<maxgap>` modifier for internal-gap filling.
The input contains three missing regions:

- An enclosed circular gap spanning 11 grid nodes in x and y.
- An enclosed circular gap spanning 29 grid nodes in x and y.
- A rectangular gap connected to the western grid boundary.

The blue, orange, and black dashed outlines identify the small, large, and
edge-connected gaps, respectively.

The mergefile contains one input record:

```text
gapped.nc - - - -
```

The limited reconstruction uses:

```bash
gmt merge2d gaps.merge2d -R0/100/0/100 -I1 -H+m12 -Glimited.nc
```

A bare `-H` selects linear Delaunay interpolation. The `+m12` modifier fills
an enclosed hole only when both its horizontal and vertical spans are no more
than 12 grid nodes. Consequently, the small blue hole is filled while the
larger orange hole remains missing.

The unrestricted reconstruction uses:

```bash
gmt merge2d gaps.merge2d -R0/100/0/100 -I1 -Hl -Gunlimited.nc
```

This fills both enclosed holes. The western gap remains missing in both
results because gaps connected to an input-grid edge are never filled.

Run:

```bash
./ex09_gap_limits.sh
```

The script samples each gap to verify the expected behavior, confirms that
the original data are unchanged, and creates `ex09_gap_limits.png` and
`ex09_gap_limits.pdf`.
