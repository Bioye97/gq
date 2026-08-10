# ex06_missing_values

This example demonstrates missing-value handling for text and NetCDF inputs.
The text primary contains `NaN`, while the text secondary uses `-99999` and
declares it with GMT's `-di-99999` option.

The equivalent NetCDF primary declares `_FillValue`. The NetCDF secondary
does not declare its sentinel, so the selector supplies it explicitly:

```text
primary.nc?vp secondary.nc?p+n-99999 0/10 cosine 0.2
```

Interpolation is performed independently within each contiguous data run and
does not bridge a missing interval. Where only the primary or secondary is
available, that value is returned regardless of the merging weight. Where
neither is available, the output is `NaN`.

Appending `+g` to the interpolation option bridges every internal missing
interval before merging:

```bash
gmt merge1d inputs.merge -T0/10/0.05 -Sl+g -Fvalue -W -Gmerged.txt
```

The final two panels compare the interpolated primary and secondary series
with the resulting merge. Missing values outside the first and last available
samples would remain missing because `+g` does not extrapolate.

Run:

```bash
./ex06_missing_values.sh
```

The script verifies that the text and NetCDF routes give numerically
equivalent results both with and without gap interpolation, checks the
missing-data cases, and creates `ex06_missing_values.png` and
`ex06_missing_values.pdf`.
