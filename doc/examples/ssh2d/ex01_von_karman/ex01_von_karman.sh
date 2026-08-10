#!/usr/bin/env bash
#
# Generate a two-dimensional von Karman heterogeneity field.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex01.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

field="${work_dir}/von_karman.nc"
cpt="${work_dir}/heterogeneity.cpt"
ps_file="${work_dir}/ex01_von_karman.ps"

gmt ssh2d -R0/100/0/100 -I0.5 -D0.05 -C8 -U0.3 -Q42 -G"${field}"
gmt makecpt -Cvik -T-0.15/0.15/0.01 > "${cpt}"

gmt grdimage "${field}?heterogeneity" -P -R0/100/0/100 -JX4.8i \
	-C"${cpt}" -Bxa20f10+l"X" -Bya20f10+l"Y" \
	-BWSen+t"Two-dimensional von Karman heterogeneity" \
	-X1.25i -Y1.5i -K > "${ps_file}"
gmt psscale -R -J -C"${cpt}" -DjBC+w4i/0.15i+h+o0/-1.0i \
	-Bxa0.05+l"Fractional perturbation" \
	--FONT_ANNOT_PRIMARY=12p --FONT_LABEL=12p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex01_von_karman"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex01_von_karman"
