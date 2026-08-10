# ex09_starting_velocity_model

This example constructs a regional one-dimensional P-wave starting model for
southern California. It uses the Hadley-Kanamori model as the shallow primary
and the continental AK135 model as both its secondary and the deeper fallback.

The Hadley-Kanamori model places layer boundaries at 5.5, 16,
and 32 km, with P-wave velocities of 5.5, 6.3, 6.7, and 7.8 km/s. The 32 km
interface is the corrected Moho depth documented by the
[U.S. Geological Survey](https://pubs.usgs.gov/of/1994/0199/report.pdf); the
model originates with
[Hadley and Kanamori (1977)](https://authors.library.caltech.edu/records/tq3ny-6te18).

The continental AK135 model has P-wave velocities of 5.8 km/s from 0 to
20 km, 6.5 km/s from 20 to 35 km, and 8.04 km/s at 35 km, followed by a
small positive upper-mantle gradient. These values and the point-wise
interpolation convention are tabulated in the
[GFZ reference-model datasheet](https://gfzpublic.gfz.de/pubman/item/item_43253/component/file_56084/DS_2.1_rev1.pdf).
AK135 was developed by Kennett, Engdahl, and Buland (1995); model information
is also available from the
[Australian National University](https://rses.anu.edu.au/seismology/ak135/intro.html).

Both profiles are sampled every 0.1 km over the requested depth ranges. The
mergefile is:

```text
Hadley AK135 - cosine 0/0.2
AK135 - - - -
```

The first taper ratio is zero, so the Hadley-Kanamori model is retained at
the surface. The bottom taper occupies the final 20 percent of its 0/32 km
domain, smoothly transferring the model to AK135 between 25.6 and 32 km.
The second record then supplies AK135 from 32 to 60 km.

The script uses `-W` to append the merging weight. The first panel compares
the two input models with the merged starting model, while the second panel
shows how the weight decreases from one to zero across the bottom taper.

Run:

```bash
./ex09_starting_velocity_model.sh
```

The script validates the merged profile and creates
`ex09_starting_velocity_model.png` and
`ex09_starting_velocity_model.pdf`.
