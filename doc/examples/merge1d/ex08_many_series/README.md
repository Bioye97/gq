# ex08_many_series

This example merges seven constant-valued primary series and one full-domain
secondary. Every series uses a spacing of `0.1`, a cosine window, and taper
ratios of `0.3/0.3`.

| Series | Domain | Value | Paired secondary |
| --- | --- | --- | --- |
| `P1` | 70/95 | 8 | `P3` |
| `P2` | 65/75 | 7 | `P3` |
| `P3` | 55/100 | 6 | `secondary` |
| `P4` | 15/35 | 5 | `P7` |
| `P5` | 37/53 | 4 | `secondary` |
| `P6` | 5/20 | 3 | `P7` |
| `P7` | 0/45 | 2 | `secondary` |
| `secondary` | 0/100 | 1 | none |

The mergefile is ordered as follows:

```text
P1 P3        - cosine 0.3/0.3
P2 P3        - cosine 0.3/0.3
P3 secondary - cosine 0.3/0.3
P4 P7        - cosine 0.3/0.3
P5 secondary - cosine 0.3/0.3
P6 P7        - cosine 0.3/0.3
P7 secondary - cosine 0.3/0.3
secondary - - - -
```

The `-` support placeholders make each window use the complete domain of its
primary series.

This creates three peer overlap groups: `P1` and `P2` use `P3`, `P4` and
`P6` use `P7`, and `P5` and `P7` use `secondary`. A shared secondary may
also appear later as a primary, but it then belongs to a lower-priority
layer and does not enter the earlier group as another primary.

Without `-A`, the first applicable record controls each overlap. With `-A`,
the weights of peer primaries are normalized within each shaded overlap.
The final unpaired `secondary` record fills any locations left by the earlier
records.

Run:

```bash
./ex08_many_series.sh
```

The script verifies full-domain coverage, confirms that aggregation changes
all three intended overlaps, and creates `ex08_many_series.png` and
`ex08_many_series.pdf`.
