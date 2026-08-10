# ex12_multiple_supports

This example compares regular and aggregate merging across six overlapping
rectangular supports. The primary grids have constant values of 9, 7, 5, 8,
6, and 4. Each primary grid domain defines its support, and every primary is
paired with the same full-domain secondary grid, which has value 1:

```text
primary1 secondary - cosine/cosine 0.30
primary2 secondary - cosine/cosine 0.30
primary3 secondary - cosine/cosine 0.30
primary4 secondary - cosine/cosine 0.30
primary5 secondary - cosine/cosine 0.30
primary6 secondary - cosine/cosine 0.30
secondary - - - -
```

Regular merging evaluates the records in order. The first available primary
therefore controls each overlap, and later primary fields appear abruptly
where an earlier support ends.

With `-A`, all primary fields having positive weights at a node contribute to
the result. Their weights are normalized together because the primaries share
the same secondary pair. This smooths the internal boundaries produced by
mergefile ordering. The final record tiles the secondary value outside the
polygon supports.

Run:

```bash
./ex12_multiple_supports.sh
```

The script reconstructs the aggregate result from all six primary weights and
the remaining secondary weight. It also verifies that aggregate and regular
merging differ only where at least two primary grid domains overlap and that
the secondary fills the background. It creates `ex12_multiple_supports.png` and
`ex12_multiple_supports.pdf`.
