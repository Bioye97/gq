# ex03_polygon_conversion

This example uses a simplified South America polygon to localize the blending
of two full-domain grids over `-R-85/-30/-60/15`. The continental outline is
not strictly xy-monotone. The primary and secondary grids have constant values
of 8 and 2, respectively. The mergefile contains:

```text
primary secondary south_america.txt cosine/cosine 0.49
secondary - - - -
```

The `-ME` option replaces the requested polygon with its strict xy-monotone
envelope before defining the window. Appending `+w` writes the converted
polygon to `south_america_monotone.txt`. Panel (d) compares the converted
support as a solid black line with the requested polygon as a dashed black
line. In panels (e) and (f), Dashed outlines show the requested polygon and
solid outlines show the converted support.

The secondary paired on the first record is used within the converted support.
The final record supplies the secondary as a fallback tile elsewhere. The `-W`
option adds the shared merging weight to the output NetCDF file.
Consequently, the merged field is `2 + 6 * weight`.

Run:

```bash
./ex03_polygon_conversion.sh
```

The script verifies that the weighted primary and secondary values reproduce
the merged grid, then creates `ex03_polygon_conversion.png` and
`ex03_polygon_conversion.pdf`.
