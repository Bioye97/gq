#!/usr/bin/env bash
#
# Apply independent, field-specific heterogeneities to several parameters.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex07.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

model="${work_dir}/model.txt"
perturbed="${work_dir}/perturbed.txt"
relative="${work_dir}/relative_perturbations.txt"

awk 'BEGIN {
	for (x = 0; x <= 100.0001; x += 0.1) {
		vp = 5.8 + 0.012 * x
		vs = 3.3 + 0.007 * x
		rho = 2.55 + 0.0025 * x
		print x, vp, vs, rho
	}
}' > "${model}"

# Shared defaults are overridden by name, while +i gives each field its own seed.
gmt ssh1d "${model}" -A -Fvp,vs,rho -D0.04 -C8 -U0.4 \
	-Dvp/0.025 -Dvs/0.05 -Drho/0.015 \
	-Cvp/12 -Cvs/6 -Crho/3 -Q73+i -G"${perturbed}"

paste "${model}" "${perturbed}" | \
	awk '{print $1, 100 * ($6 / $2 - 1), 100 * ($7 / $3 - 1),
	             100 * ($8 / $4 - 1)}' > "${relative}"

projection=X6.9i/1.7i
region=0/100/-15/15
ps_file="${work_dir}/ex07_multiple_parameters.ps"

gmt psbasemap -P -R${region} -J${projection} -Bxa20f10 \
	-Bya5f2.5+l"Perturbation (%)" -BWSen+t"(a) Vp: sigma 2.5%, length 12" \
	-X0.8i -Y5.8i -K > "${ps_file}"
gmt psxy "${relative}" -i0,1 -R -J -W1.5p,royalblue -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa20f10 \
	-Bya5f2.5+l"Perturbation (%)" -BWSen+t"(b) Vs: sigma 5%, length 6" \
	-Y-2.5i -O -K >> "${ps_file}"
gmt psxy "${relative}" -i0,2 -R -J -W1.5p,orangered -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya5f2.5+l"Perturbation (%)" -BWSen+t"(c) Density: sigma 1.5%, length 3" \
	-Y-2.5i -O -K >> "${ps_file}"
gmt psxy "${relative}" -i0,3 -R -J -W1.5p,seagreen -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex07_multiple_parameters"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex07_multiple_parameters"
