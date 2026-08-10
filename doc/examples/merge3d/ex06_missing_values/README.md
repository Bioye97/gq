# ex06_missing_values

This example extends the missing-value configuration from merge2d `ex07` into
three dimensions. The primary model has value 8 and occupies `15/85` along x,
y, and z. It stores a rectangular missing block as its declared NetCDF fill
value. This block is internal in x-y but touches the lower z boundary. The
secondary model has value 2, covers the full `0/100` cube, and uses the
undeclared sentinel `-99999` for a perpendicular block that touches the west
x boundary but is internal along z.

At `z = 50 km`, the primary and secondary gaps reproduce the vertical and
horizontal bands from the two-dimensional example. Their z extents make the
same missing-value relationships visible in a vertical section along
`y = 50 km`.

The mergefile is:

```text
primary.nc?vp secondary.nc?p - - cosine/cosine/cosine 0.25
secondary.nc?p - - - - -
```

The symmetric cosine taper operates at both ends of x, y, and z. GMT's common
input option `-di-99999` converts the undeclared secondary sentinel to `NaN`.
Without internal-gap interpolation, `merge3d` retains the available model
where only one member is missing and returns `NaN` where both are missing.
The merging weight depends only on the primary support and is not altered by
data availability.

The `-Hl` option fills the primary's internal x-y holes with linear Delaunay
interpolation. The secondary gap is connected to an x-y boundary and is
therefore preserved by `-H`, but `-Sl+g` bridges its internal missing z layers.
Together, the options fill both orthogonal gaps before merging:

```bash
gmt merge3d missing.merge3d -R0/100/0/100 -I1 -T0/100/1 \
    -Fvp -di-99999 -Hl -Sl+g -W -nl -Gfilled.nc
```

Panels (a-e) show horizontal slices at `z = 50 km`; panels (f-j) show vertical
sections along `y = 50 km`. Blue outlines mark the primary gap, orange outlines
mark the secondary gap, and the dashed black line marks the vertical-section
location. The primary support is outlined in the input and weight panels.

Run:

```bash
./ex06_missing_values.sh
```

The script checks primary-only, secondary-only, and jointly missing samples in
both views. After horizontal and vertical interpolation, it verifies the
complete result against `merged = 2 + 6 * weight`. It creates
`ex06_missing_values.png` and `ex06_missing_values.pdf`.
