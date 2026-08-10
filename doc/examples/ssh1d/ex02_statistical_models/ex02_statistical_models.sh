#!/usr/bin/env bash
#
# Compare the statistical models available in ssh1d.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex02.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

gmt ssh1d -T0/100/0.1 -D0.05 -C6 -U0.15 -Mv -Q24 \
	-G"${work_dir}/von_karman.txt"
gmt ssh1d -T0/100/0.1 -D0.05 -C6 -Mg -Q24 \
	-G"${work_dir}/gaussian.txt"
gmt ssh1d -T0/100/0.1 -D0.05 -C6 -Me -Q24 \
	-G"${work_dir}/exponential.txt"
gmt ssh1d -T0/100/0.1 -D0.05 -Mw -Q24 \
	-G"${work_dir}/white.txt"

region=0/100/-0.2/0.2
projection=X3.15i/2.25i
ps_file="${work_dir}/ex02_statistical_models.ps"

gmt psbasemap -P -R${region} -J${projection} -Bxa20f10 \
	-Bya0.1f0.05+l"Fractional perturbation" -BWSen+t"(a) Von Karman" \
	-X0.8i -Y5.2i -K > "${ps_file}"
gmt psxy "${work_dir}/von_karman.txt" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa20f10 -Bya0.1f0.05 \
	-BWSen+t"(b) Gaussian" -X3.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/gaussian.txt" -R -J -W1.5p,seagreen -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya0.1f0.05+l"Fractional perturbation" -BWSen+t"(c) Exponential" \
	-X-3.75i -Y-3.0i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/exponential.txt" -R -J -W1.5p,orangered -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya0.1f0.05 -BWSen+t"(d) White noise" -X3.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/white.txt" -R -J -W1p,mediumorchid -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex02_statistical_models"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex02_statistical_models"
