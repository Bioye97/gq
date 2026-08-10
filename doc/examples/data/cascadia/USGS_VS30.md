# USGS Global Hybrid Vs30 Mosaic

`USGS_global_vs30_cascadia.nc` is a server-side crop of the USGS Global Hybrid
Vs30 Mosaic for longitude/latitude = `-130/-116/39/52`.

Source:

- <https://earthquake.usgs.gov/data/vs30/>
- <https://earthquake.usgs.gov/arcgis/rest/services/gp/VS30_extract/GPServer/Extract%20Data>

The USGS describes the model as a global topographic-slope-based mosaic with
embedded regional maps, following Heath et al. (2020). The source resolution
is 30 arc-seconds and Vs30 is expressed in meters per second. The source model
uses 600 m/s in water-covered areas.

The cached NetCDF grid was requested in WGS84 through the official USGS
extraction service and converted from the delivered GeoTIFF with GMT. Its
pixel registration and native 30-arc-second spacing are retained.

The delivered Cascadia crop contains a small number of values below the
documented 98 m/s lower limit. The `elygtl` examples treat those values as
missing before sampling the grid; the cached source crop remains unchanged.

Run `download_usgs_vs30.sh` to reproduce the download. The script requests
only the Cascadia crop, avoiding the approximately 582 MB global grid.
