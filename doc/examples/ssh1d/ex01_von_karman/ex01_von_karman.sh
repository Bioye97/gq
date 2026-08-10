#!/usr/bin/env bash
#
# Generate a one-dimensional von Karman heterogeneity field.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex01.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

field="${work_dir}/von_karman.txt"
spectrum="${work_dir}/von_karman_spectrum.txt"
ps_file="${work_dir}/ex01_von_karman.ps"

gmt ssh1d -T0/100/0.1 -D0.05 -C5 -U0.3 -Q42 -G"${field}"
gmt spectrum1d "${field}" -i1 -D256 -D0.1 -N > "${spectrum}"

# Panel (a): the fractional heterogeneity field.
gmt psbasemap -P -R0/100/-0.16/0.16 -JX3.15i/2.35i \
	-Bxa20f10+l"Coordinate" -Bya0.08f0.04+l"Fractional perturbation" \
	-BWSen+t"(a) Von Karman heterogeneity" -X0.8i -Y2.0i -K > "${ps_file}"
gmt psxy "${field}" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy -R -J -W0.6p,gray50,- -O -K >> "${ps_file}" <<- EOF
	0 0
	100 0
	EOF

# Panel (b): the corresponding power spectrum.
gmt psbasemap -R0.035/5/0.000001/0.03 -JX3.15il/2.35il \
	-Bxa2f3+l"Spatial frequency" -Bya1pf3+l"Power" \
	-BWSen+t"(b) Power spectrum" -X3.75i -O -K >> "${ps_file}"
gmt psxy "${spectrum}" -i0,1 -R -J -W1.5p,orangered -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex01_von_karman"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex01_von_karman"
