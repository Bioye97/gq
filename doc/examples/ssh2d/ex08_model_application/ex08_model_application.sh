#!/usr/bin/env bash
#
# Apply two-dimensional heterogeneity to a synthetic velocity grid.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex08.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

model="${work_dir}/velocity.nc"
perturbed="${work_dir}/perturbed.nc"
gmt grdmath -R0/100/0/100 -I1 5.5 X 0.012 MUL ADD Y 0.006 MUL ADD \
	X 12 DIV SIN 0.2 MUL ADD = "${model}"
gmt ssh2d "${model}" -A -Fz -D0.04 -C10/6 -U0.35 -Q37 -G"${perturbed}"
gmt grdmath "${perturbed}?z" "${model}" SUB = "${work_dir}/difference.nc"
gmt makecpt -Cbatlow -T5/7.5/0.1 > "${work_dir}/velocity.cpt"
gmt makecpt -Cvik -T-0.8/0.8/0.05 > "${work_dir}/difference.cpt"

ps_file="${work_dir}/ex08_model_application.ps"
projection=X2.0i
gmt grdimage "${model}" -P -R0/100/0/100 -J${projection} \
	-C"${work_dir}/velocity.cpt" -Bxa20f10+l"X" -Bya20f10+l"Y" \
	-BWSen+t"(a) Original model" -X0.6i -Y2.0i -K > "${ps_file}"
gmt grdimage "${perturbed}?z" -R -J -C"${work_dir}/velocity.cpt" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(b) Perturbed model" \
	-X2.55i -O -K >> "${ps_file}"
gmt grdimage "${work_dir}/difference.nc" -R -J -C"${work_dir}/difference.cpt" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(c) Difference" \
	-X2.55i -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/velocity.cpt" \
	-DjBC+w3.2i/0.15i+h+o-3.0i/-1.0i -Bxa0.5+l"Velocity (km/s)" \
	--FONT_ANNOT_PRIMARY=14p --FONT_LABEL=14p -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/difference.cpt" \
	-DjBC+w2.0i/0.15i+h+o0/-1.0i -Bxa0.4+l"Difference (km/s)" \
	--FONT_ANNOT_PRIMARY=17p --FONT_LABEL=17p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex08_model_application"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex08_model_application"
