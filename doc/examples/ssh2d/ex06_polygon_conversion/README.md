# ex06_polygon_conversion

This example applies `ssh2d` to the non-monotone South America polygon used
by the merge examples. The `-EE+w` option constructs and writes the monotone
envelope before applying a cosine taper with a ratio of 0.3.

Panel (a) shows the untapered perturbation and original polygon, panel (b)
shows the envelope taper weight, and panel (c) shows the resulting tapered
perturbation. The original and converted outlines are plotted together in
panels (b) and (c).

Run:

```bash
./ex06_polygon_conversion.sh
```

The script creates `ex06_polygon_conversion.png` and
`ex06_polygon_conversion.pdf`.
