#!/usr/bin/env bash
#
# Taper a two-dimensional heterogeneity field inside a polygon support.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex05.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

polygon="${work_dir}/diamond.txt"
cat > "${polygon}" <<- EOF
	50 12
	88 50
	50 88
	12 50
	EOF

gmt ssh2d -R0/100/0/100 -I0.5 -D0.05 -C7 -U0.3 -Q55 -G"${work_dir}/raw.nc"
gmt ssh2d -R0/100/0/100 -I0.5 -D0.05 -C7 -U0.3 -Q55 \
	-P"${polygon}" -Wcosine+r0.3+w -G"${work_dir}/tapered.nc"
gmt makecpt -Cvik -T-0.16/0.16/0.01 > "${work_dir}/heterogeneity.cpt"
gmt makecpt -Chot -T0/1/0.05 > "${work_dir}/weight.cpt"

ps_file="${work_dir}/ex05_polygon_support.ps"
projection=X2.15i
gmt grdimage "${work_dir}/raw.nc?heterogeneity" -P -R0/100/0/100 -J${projection} \
	-C"${work_dir}/heterogeneity.cpt" -Bxa20f10+l"X" -Bya20f10+l"Y" \
	-BWSen+t"(a) Untapered" -X0.7i -Y2.0i -K > "${ps_file}"
gmt psxy "${polygon}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"

gmt grdimage "${work_dir}/tapered.nc?heterogeneity" -R -J \
	-C"${work_dir}/heterogeneity.cpt" -Bxa20f10+l"X" -Bya20f10 \
	-BWSen+t"(b) Polygon taper" -X2.75i -O -K >> "${ps_file}"
gmt psxy "${polygon}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"

gmt grdimage "${work_dir}/tapered.nc?weight" -R -J -C"${work_dir}/weight.cpt" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(c) Taper weight" \
	-X2.75i -O -K >> "${ps_file}"
gmt psxy "${polygon}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/heterogeneity.cpt" \
	-DjBC+w4.2i/0.15i+h+o-4.125i/-1.0i \
	-Bxa0.08+l"Fractional perturbation" \
	--FONT_ANNOT_PRIMARY=12p --FONT_LABEL=12p -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/weight.cpt" \
	-DjBC+w1.9i/0.15i+h+o0/-1.0i -Bxa0.25+l"Weight" \
	--FONT_ANNOT_PRIMARY=16p --FONT_LABEL=16p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex05_polygon_support"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex05_polygon_support"
