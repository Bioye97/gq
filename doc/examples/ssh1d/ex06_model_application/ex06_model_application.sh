#!/usr/bin/env bash
#
# Apply a fractional heterogeneity field to a one-dimensional velocity model.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex06.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

model="${work_dir}/velocity_model.txt"
field="${work_dir}/heterogeneity.txt"
perturbed="${work_dir}/perturbed_model.txt"

awk 'BEGIN {
	for (depth = 0; depth <= 60.0001; depth += 0.1) {
		vp = 5.4 + 0.025 * depth + (depth >= 18 ? 0.35 : 0)
		print depth, vp
	}
}' > "${model}"

gmt ssh1d -T0/60/0.1 -D0.04 -C3 -U0.3 -Q37 -G"${field}"
gmt ssh1d "${model}" -A -Fvp -D0.04 -C3 -U0.3 -Q37 \
	-G"${perturbed}"

cat > "${work_dir}/model.legend" <<- EOF
	S 0.08i - 0.22i - 1.5p,gray40 0.28i Original model
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Perturbed model
	EOF

ps_file="${work_dir}/ex06_model_application.ps"

gmt psbasemap -P -R-0.14/0.14/0/60 -JX3.15i/-3.8i \
	-Bxa0.07f0.035+l"Fractional perturbation" -Bya10f5+l"Depth (km)" \
	-BWSen+t"(a) Heterogeneity" -X0.8i -Y1.4i -K > "${ps_file}"
gmt psxy "${field}" -i1,0 -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy -R -J -W0.6p,gray50,- -O -K >> "${ps_file}" <<- EOF
	0 60
	0 0
	EOF

gmt psbasemap -R5.2/7.6/0/60 -JX3.15i/-3.8i \
	-Bxa0.5f0.25+l"P-wave velocity (km/s)" -Bya10f5 \
	-BWSen+t"(b) Model application" -X3.75i -O -K >> "${ps_file}"
gmt psxy "${model}" -i1,0 -R -J -W1.5p,gray40 -O -K >> "${ps_file}"
gmt psxy "${perturbed}" -i1,0 -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/model.legend" -R -J -DjTR+o0.08i \
	-F+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex06_model_application"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex06_model_application"
