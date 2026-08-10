# ex06_layer_selection

This example selects two layers directly from a three-dimensional NetCDF
variable and merges them as two-dimensional grids. The model contains `vp` at
depths 0, 10, 20, and 30 km.

Square brackets select a zero-based layer index, so `vp[1]` selects the 10 km
layer. Parentheses select the layer whose coordinate is nearest the requested
value, so `vp(28)` selects the 30 km layer. Coordinate selection does not
interpolate between layers.

The mergefile is:

```text
model3d.nc?vp[1] model3d.nc?vp(28) diamond.txt cosine/cosine 0.3
model3d.nc?vp(28) - - - -
```

The 10 km layer is primary within the diamond-shaped support. It merges into the
selected 30 km layer using a symmetric cosine taper. The final record tiles
the 30 km layer into the rest of the output domain.

Run:

```bash
./ex06_layer_selection.sh
```

The script verifies both layer selections and reconstructs the weighted merge
at every output node. It creates `ex06_layer_selection.png` and
`ex06_layer_selection.pdf`.
