# ex02_pnw10_s

This example applies the USGS Global Hybrid Vs30 Mosaic to the Vs-only
PNW10-S model. PNW10-S has a flat surface at zero elevation, and GMT's GSHHG
classification prevents the GTL from being applied in oceanic columns.

The upper 2.5 km is interpolated from the native model to 50 m vertical
spacing before the default 350 m Ely transition is constructed. The command
converts elevation and velocity from kilometers and kilometers per second to
the SI units required by the Ely equations while preserving those original
units in the output.

The maps and the 47 N sections compare the original model with the GTL result.

Run:

```bash
./ex02_pnw10_s.sh
```

The script creates:

- `ex02_pnw10_s.png`
- `ex02_pnw10_s.pdf`
