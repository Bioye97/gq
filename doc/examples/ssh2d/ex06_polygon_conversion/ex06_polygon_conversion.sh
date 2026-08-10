#!/usr/bin/env bash
#
# Convert a non-monotone polygon before tapering a heterogeneity field.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex06.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

source_polygon="${script_dir}/../../merge2d/ex03_polygon_conversion/south_america.txt"
envelope_polygon="${work_dir}/south_america_envelope.txt"
cp "${source_polygon}" "${envelope_polygon}"

gmt ssh2d -R-85/-30/-60/15 -I0.25 -D0.05 -C5 -U0.3 -Q29 \
	-G"${work_dir}/untapered.nc"
gmt ssh2d -R-85/-30/-60/15 -I0.25 -D0.05 -C5 -U0.3 -Q29 \
	-P"${envelope_polygon}" -EE+w -Wcosine+r0.3+w \
	-G"${work_dir}/envelope.nc"
gmt makecpt -Chot -T0/1/0.05 > "${work_dir}/weight.cpt"
gmt makecpt -Cvik -T-0.16/0.16/0.01 > "${work_dir}/heterogeneity.cpt"

ps_file="${work_dir}/ex06_polygon_conversion.ps"
projection=X2.15i/2.9i
gmt grdimage "${work_dir}/untapered.nc?heterogeneity" -P \
	-R-85/-30/-60/15 -J${projection} -C"${work_dir}/heterogeneity.cpt" \
	-Bxa20f10+l"Longitude" -Bya20f10+l"Latitude" \
	-BWSen+t"(a) Original polygon" -X0.7i -Y2.0i -K > "${ps_file}"
gmt psxy "${source_polygon}" -R -J -L -W1.5p,black -O -K >> "${ps_file}"

gmt grdimage "${work_dir}/envelope.nc?weight" -R -J -C"${work_dir}/weight.cpt" \
	-Bxa20f10+l"Longitude" -Bya20f10 -BWSen+t"(b) Envelope (-EE)" \
	-X2.75i -O -K >> "${ps_file}"
gmt psxy "${source_polygon}" -R -J -L -W1p,black,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/south_america_envelope_monotone.txt" -R -J -L \
	-W1.5p,orangered -O -K >> "${ps_file}"

gmt grdimage "${work_dir}/envelope.nc?heterogeneity" -R -J \
	-C"${work_dir}/heterogeneity.cpt" \
	-Bxa20f10+l"Longitude" -Bya20f10 -BWSen+t"(c) Perturbation" \
	-X2.75i -O -K >> "${ps_file}"
gmt psxy "${source_polygon}" -R -J -L -W1p,black,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/south_america_envelope_monotone.txt" -R -J -L \
	-W1.5p,orangered -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/weight.cpt" \
	-DjBC+w1.9i/0.15i+h+o-2.75i/-1.05i -Bxa0.25+l"Weight" \
	--FONT_ANNOT_PRIMARY=16p --FONT_LABEL=16p -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/heterogeneity.cpt" \
	-DjBC+w1.9i/0.15i+h+o0/-1.05i -Bxa0.08+l"Fractional perturbation" \
	--FONT_ANNOT_PRIMARY=16p --FONT_LABEL=16p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex06_polygon_conversion"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex06_polygon_conversion"
