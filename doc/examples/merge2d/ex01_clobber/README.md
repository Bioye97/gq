# ex01_clobber

This example compares the four `merge2d` clobber modes for two directly
listed grids:

- `-Cf` retains the first value and is the default.
- `-Co` retains the last value.
- `-Cl` retains the lowest value.
- `-Cu` retains the highest value.

Grid A and Grid B overlap within `-R3/7/3/7`, shown by the dashed square.
Outside the overlap, each mode retains whichever input is
available. Areas not covered by either grid remain undefined.

Run:

```bash
./ex01_clobber.sh
```

The script verifies that the default result is identical to explicit `-Cf`
and creates `ex01_clobber.png` and `ex01_clobber.pdf`.
