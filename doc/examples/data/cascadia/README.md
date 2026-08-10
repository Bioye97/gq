# Cascadia model cache

This directory caches public NetCDF models and their horizontal and vertical
parameter slices used by the Cascadia examples. The large NetCDF files are
intentionally excluded from version control and reused on subsequent runs.

Run `prepare_vs_slices.sh` to populate the cache. The plotting-only model
overview is provided by `plot_vs_slices.sh` and documented in `PLOTTING.md`.

Run `download_usgs_vs30.sh` to download only the Cascadia crop of the USGS
Global Hybrid Vs30 Mosaic. Its source and processing details are documented
in `USGS_VS30.md`. The `elygtl` Cascadia examples reuse this cached grid.

The plotting script creates:

- `cascadia_vs_slices.png` and `cascadia_vs_slices.pdf`
- `cascadia_vs_vertical_slices.png` and
  `cascadia_vs_vertical_slices.pdf`
