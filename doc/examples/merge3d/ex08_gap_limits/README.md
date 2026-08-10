# ex08_gap_limits

This example extends the gap-size limit from merge2d `ex09` into three
dimensions. A smooth reference model contains three missing cylinders:

- A small internal gap with a 16 km distance between its finite z brackets.
- A large internal gap with a 44 km bracketing distance.
- A gap connected to the top of the model at `z = 0`.

The limited reconstruction uses:

```bash
gmt merge3d model.nc?gapped -R0/100/0/100 -I2 -T0/100/1 \
    -Fvalue -Sl+g20 -nl -Glimited.nc
```

The `+g20` modifier bridges a missing vertical run only when the distance
between its finite z brackets is no more than 20 km. Consequently, the small
gap is filled while the large gap remains missing. The unrestricted result
uses `-Sl+g` and fills both internal gaps.

The gap touching `z = 0` remains missing in both reconstructions because gap
bridging does not extrapolate beyond the vertical coordinate range of finite
data. The limit is evaluated independently for every vertical column; it is a
z-coordinate distance, not a three-dimensional diameter.

This example intentionally omits `-H` because it isolates the vertical
z-distance limit. The separate `-H+m<maxgap>` modifier limits horizontal holes
by their x and y spans in grid nodes, matching `merge2d`.

Panels (a-d) show horizontal slices at `z = 50 km`. Panels (e-h) show vertical
sections along `y = 50 km`, where the top-connected gap is also visible. Blue,
orange, and black dashed outlines identify the small, large, and edge-connected
gaps, respectively. The dashed black line in the horizontal panels marks the
vertical-section location.

Run:

```bash
./ex08_gap_limits.sh
```

The script verifies the expected state of all three gaps for the original,
limited, and unrestricted results. It creates `ex08_gap_limits.png` and
`ex08_gap_limits.pdf`.
