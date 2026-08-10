# ex03_polygon_conversion

This example localizes a three-dimensional merge with a simplified South
America polygon. The requested outline is not strictly xy-monotone, so it must
be converted before BLEND can define the horizontal window. The primary and
secondary cubes contain constant values of 8 and 2, respectively.

The mergefile contains:

```text
primary secondary south_america.txt 20/80 cosine/cosine/cosine 0.49
secondary - - - - -
```

`-ME` replaces the requested polygon with its strict xy-monotone envelope.
Appending `+w` writes that envelope to `south_america_monotone.txt`. The
horizontal footprint is extruded through the specified `20/80` z interval, and
the 0.49 cosine taper is applied at both ends of all three dimensions.

Panels (a-d) show the inputs, requested polygon, and converted envelope. Panels
(e-f) show the horizontal weight and merged result at `z = 50`. Panels (g-h)
show vertical sections along latitude `-20`; the horizontal lines mark
the z support. In the horizontal weight panel, blue marks the requested polygon
and orange marks the converted envelope.

Because both inputs are constant, the merged field is `2 + 6 * weight`. The
script verifies this relationship in both the horizontal and vertical views.

Run:

```bash
./ex03_polygon_conversion.sh
```

The script creates `south_america_monotone.txt`,
`ex03_polygon_conversion.png`, and `ex03_polygon_conversion.pdf`.
