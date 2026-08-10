# ex01_clobber

This example compares the four `merge1d` clobber modes for two directly
listed text series:

- `-Cf` retains the first value and is the default.
- `-Co` retains the last value.
- `-Cl` retains the lowest value.
- `-Cu` retains the highest value.

The inputs overlap between coordinates 4 and 10. Within that interval,
`-Co+n` permits only non-positive values from later inputs to replace an
existing value, while `-Co+p` permits only non-negative replacements. Initial
values outside an overlap remain eligible regardless of sign.

Run:

```bash
./ex01_clobber.sh
```

The script verifies that the default result is identical to explicit `-Cf`
and creates `ex01_clobber.png` and `ex01_clobber.pdf`.
