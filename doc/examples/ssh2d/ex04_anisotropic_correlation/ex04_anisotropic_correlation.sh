#!/usr/bin/env bash
#
# Introduce axis-aligned anisotropy with different correlation lengths.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex04.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

gmt ssh2d -R0/100/0/100 -I0.5 -D0.05 -C8 -U0.35 -Q63 -G"${work_dir}/isotropic.nc"
gmt ssh2d -R0/100/0/100 -I0.5 -D0.05 -C20/4 -U0.35 -Q63 -G"${work_dir}/anisotropic.nc"
gmt makecpt -Cvik -T-0.16/0.16/0.01 > "${work_dir}/heterogeneity.cpt"

ps_file="${work_dir}/ex04_anisotropic_correlation.ps"
gmt grdimage "${work_dir}/isotropic.nc?heterogeneity" -P -R0/100/0/100 -JX3.15i \
	-C"${work_dir}/heterogeneity.cpt" -Bxa20f10+l"X" -Bya20f10+l"Y" \
	-BWSen+t"(a) Isotropic: 8/8" -X0.8i -Y2.0i -K > "${ps_file}"
gmt grdimage "${work_dir}/anisotropic.nc?heterogeneity" -R -J \
	-C"${work_dir}/heterogeneity.cpt" -Bxa20f10+l"X" -Bya20f10 \
	-BWSen+t"(b) Anisotropic: 20/4" -X3.75i -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/heterogeneity.cpt" \
	-DjBC+w4.8i/0.15i+h+o-1.875i/-1.0i \
	-Bxa0.04+l"Fractional perturbation" \
	--FONT_ANNOT_PRIMARY=11p --FONT_LABEL=11p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex04_anisotropic_correlation"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex04_anisotropic_correlation"
