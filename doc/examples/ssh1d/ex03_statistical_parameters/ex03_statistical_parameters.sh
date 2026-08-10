#!/usr/bin/env bash
#
# Show how the ssh1d statistical parameters alter a realization.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex03.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

common=(-T0/100/0.1 -Q81)
gmt ssh1d "${common[@]}" -D0.03 -C6 -U0.35 -G"${work_dir}/sigma_low.txt"
gmt ssh1d "${common[@]}" -D0.10 -C6 -U0.35 -G"${work_dir}/sigma_high.txt"
gmt ssh1d "${common[@]}" -D0.05 -C2 -U0.35 -G"${work_dir}/corr_short.txt"
gmt ssh1d "${common[@]}" -D0.05 -C15 -U0.35 -G"${work_dir}/corr_long.txt"
gmt ssh1d "${common[@]}" -D0.05 -C6 -U0.15 -G"${work_dir}/hurst_low.txt"
gmt ssh1d "${common[@]}" -D0.05 -C6 -U0.85 -G"${work_dir}/hurst_high.txt"

cat > "${work_dir}/sigma.legend" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i sigma = 0.03
	S 0.08i - 0.22i - 1.5p,orangered 0.28i sigma = 0.10
	EOF
cat > "${work_dir}/correlation.legend" <<- EOF
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i length = 2
	S 0.08i - 0.22i - 1.5p,mediumorchid 0.28i length = 15
	EOF
cat > "${work_dir}/hurst.legend" <<- EOF
	S 0.08i - 0.22i - 1.5p,deepskyblue 0.28i H = 0.15
	S 0.08i - 0.22i - 1.5p,darkorange 0.28i H = 0.85
	EOF

region=0/100/-0.30/0.30
projection=X6.9i/1.75i
ps_file="${work_dir}/ex03_statistical_parameters.ps"

gmt psbasemap -P -R${region} -J${projection} -Bxa20f10 \
	-Bya0.15f0.05+l"Fractional perturbation" \
	-BWSen+t"(a) Standard deviation" -X0.8i -Y6.0i -K > "${ps_file}"
gmt psxy "${work_dir}/sigma_low.txt" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/sigma_high.txt" -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/sigma.legend" -R -J -DjBR+o0.08i -F+p0.4p -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa20f10 \
	-Bya0.15f0.05+l"Fractional perturbation" \
	-BWSen+t"(b) Correlation length" -Y-2.55i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/corr_short.txt" -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt psxy "${work_dir}/corr_long.txt" -R -J -W1.5p,mediumorchid -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/correlation.legend" -R -J -DjTR+o0.08i -F+p0.4p -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya0.15f0.05+l"Fractional perturbation" \
	-BWSen+t"(c) Hurst exponent" -Y-2.55i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/hurst_low.txt" -R -J -W1.5p,deepskyblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/hurst_high.txt" -R -J -W1.5p,darkorange -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/hurst.legend" -R -J -DjTR+o0.08i -F+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex03_statistical_parameters"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex03_statistical_parameters"
