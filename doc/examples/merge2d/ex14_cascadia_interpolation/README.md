# ex14_cascadia_interpolation

This example repeats the SVI EQTOMO, Cascadia ANT+RF, and WUS324 comparison
from `ex13_cascadia_models`, but uses `-Hl` to fill all strictly internal gaps
with linear interpolation before tiling or merging.

The mergefile is:

```text
SVI_EQTOMO WUS324 - cosine/cosine 0.2
Cascadia_ANT+RF WUS324 - cosine/cosine 0.2
WUS324 - - - -
```

Panel (a) shows first-availability tiling after interpolation, panel (b) shows
regular symmetric cosine merging, and panel (c) shows aggregate merging. The
two primary domains are outlined only in panel (a). The `-P` option fills any
primary values that remain missing after interpolation from WUS324.

Run:

```bash
./ex14_cascadia_interpolation.sh
```

The script creates `ex14_cascadia_interpolation.png` and
`ex14_cascadia_interpolation.pdf`.
