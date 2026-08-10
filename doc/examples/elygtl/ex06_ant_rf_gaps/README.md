# ex06_ant_rf_gaps

This example revisits the Cascadia ANT+RF model from `ex01_ant_rf`. Before
applying the Ely GTL, it fills strictly internal horizontal holes with linear
Delaunay interpolation (`-Hl`) and bridges internal vertical gaps with linear
interpolation (`-Sl+g`). Missing regions connected to the model boundary remain
missing.

The transition thickness is supplied as a grid through `-E`. It increases
linearly from 100 m in the southwest to 1000 m in the northeast. Seven native
model layers spanning depths from -3 to 3 km are staged so that every retained
column has room for the spatially variable transition and its deeper anchor.
The model remains on an increasing, positive-down depth axis during processing;
only the plotted sections are flipped to positive-up elevation.

The figure follows `ex01_ant_rf` and adds the transition-thickness grid to the
map row. It also shows Vs30, surface Vs, and a section along 47 N. The difference
panel contains both the internal-gap filling and the Ely GTL modification.

Run:

```bash
./ex06_ant_rf_gaps.sh
```

The script creates:

- `ex06_ant_rf_gaps.png`
- `ex06_ant_rf_gaps.pdf`
