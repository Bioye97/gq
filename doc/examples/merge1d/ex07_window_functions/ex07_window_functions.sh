#!/usr/bin/env bash
#
# Compare all 53 unique BLEND window functions through merge1d weights.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex07-windows.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 7p FONT_LABEL 8p FONT_TITLE 8p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 10p

primary="${work_dir}/primary.txt"
secondary="${work_dir}/secondary.txt"
range=0/100/0.1
region=0/100/-0.05/1.05
projection=X1.35i/1.1i
projection_remaining=X1.35i/1.0i
ps_file="${work_dir}/ex07_window_functions.ps"
remaining_ps_file="${work_dir}/ex07_window_functions_remaining.ps"

windows=(
	boxcar cosine trapezoid hamming blackman
	blackmanharris welch parzen gaussian smoothstep
	smootherstep exponential sine bohman nuttall
	kaiser cauchy quadratic cubic bartlett
	bartletthann lanczos hanningpoisson plancktaper logistic
)
labels=(
	"Boxcar" "Cosine" "Trapezoid" "Hamming" "Blackman"
	"Blackman-Harris" "Welch" "Parzen" "Gaussian" "Smoothstep"
	"Smootherstep" "Exponential" "Sine" "Bohman" "Nuttall"
	"Kaiser" "Cauchy" "Quadratic" "Cubic" "Bartlett"
	"Bartlett-Hann" "Lanczos" "Hanning-Poisson" "Planck taper" "Logistic"
)
remaining_windows=(
	poisson exactblackman blackmannuttall flattop riesz
	riemann fejer connes kaiserbessel quartic
	quintic septic nonic tanh erf
	arctan gompertz softsign agnesi inversequadratic
	inversemultiquadric powerlaw root circular sech
	sech2 student laplace
)
remaining_labels=(
	"Poisson" "Exact Blackman" "Blackman-Nuttall" "Flat top" "Riesz"
	"Riemann" "Fejer" "Connes" "Kaiser-Bessel" "Quartic"
	"Quintic" "Septic" "Nonic" "Tanh" "Erf"
	"Arctan" "Gompertz" "Softsign" "Agnesi" "Inverse quadratic"
	"Inverse multiquadric" "Power law" "Root" "Circular" "Sech"
	"Sech squared" "Student" "Laplace"
)
all_windows=("${windows[@]}" "${remaining_windows[@]}")

# Constant inputs make the merged value a scaled copy of the merging weight.
awk 'BEGIN {for (x = 10; x <= 90; x++) print x, 8}' > "${primary}"
awk 'BEGIN {for (x = 0; x <= 100; x++) print x, 2}' > "${secondary}"

# Generate the same support and symmetric taper with every unique function.
for function in "${all_windows[@]}"; do
	mergefile="${work_dir}/${function}.merge"
	result="${work_dir}/${function}.txt"
	cat > "${mergefile}" <<- EOF
		${primary} ${secondary} 20/80 ${function} 0.49/0.49
		${secondary} - - - -
		EOF
	gmt merge1d "${mergefile}" -T${range} -Fvalue -W -G"${result}"

	# Every weight must remain in [0, 1] and reproduce the merged value.
	awk 'tolower($2) == "nan" || $3 < -1e-12 || $3 > 1.000000000001 ||
	     ($2 - (2 + 6 * $3))^2 > 1e-12 {exit 1}' "${result}"
done

cat > "${work_dir}/support_edges.txt" <<- EOF
	20 -0.05
	20 1.05
	>
	80 -0.05
	80 1.05
	EOF

# Plot 25 functions in five columns by five rows.
for ((index = 0; index < ${#windows[@]}; index++)); do
	function=${windows[index]}
	row=$((index / 5))
	column=$((index % 5))
	title="($((index + 1))) ${labels[index]}"
	west=w
	south=s
	((column == 0)) && west=W
	((row == 4)) && south=S
	frame="-B${west}${south}en+t${title}"
	x_axis=-Bxa50f25
	y_axis=-Bya0.5f0.25
	((row == 4 && column == 2)) && x_axis=-Bxa50f25+l"Coordinate"
	((row == 2 && column == 0)) && y_axis=-Bya0.5f0.25+l"Merging weight"

	if ((index == 0)); then
		gmt psbasemap -P -R${region} -J${projection} "${x_axis}" "${y_axis}" \
			"${frame}" -X0.55i -Y8.0i -K > "${ps_file}"
	elif ((column == 0)); then
		gmt psbasemap -R -J "${x_axis}" "${y_axis}" "${frame}" \
			-X-6.2i -Y-1.55i -O -K >> "${ps_file}"
	else
		gmt psbasemap -R -J "${x_axis}" "${y_axis}" "${frame}" \
			-X1.55i -O -K >> "${ps_file}"
	fi
	gmt psxy "${work_dir}/support_edges.txt" -R -J -W0.5p,gray65,- \
		-O -K >> "${ps_file}"
	if ((index + 1 == ${#windows[@]})); then
		gmt psxy "${work_dir}/${function}.txt" -i0,2 -R -J \
			-W1.5p,deepskyblue -O >> "${ps_file}"
	else
		gmt psxy "${work_dir}/${function}.txt" -i0,2 -R -J \
			-W1.5p,deepskyblue -O -K >> "${ps_file}"
	fi
done

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex07_window_functions"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex07_window_functions"

# Plot the remaining 28 functions in five columns, centering the final row.
for ((index = 0; index < ${#remaining_windows[@]}; index++)); do
	function=${remaining_windows[index]}
	row=$((index / 5))
	column=$((index % 5))
	if ((index >= 25)); then
		column=$((index - 24))
	fi
	title="($((index + ${#windows[@]} + 1))) ${remaining_labels[index]}"
	west=w
	south=s
	((column == 0)) && west=W
	((row == 5)) && south=S
	frame="-B${west}${south}en+t${title}"
	x_axis=-Bxa50f25
	y_axis=-Bya0.5f0.25
	((row == 5 && column == 2)) && x_axis=-Bxa50f25+l"Coordinate"
	((row == 2 && column == 0)) && y_axis=-Bya0.5f0.25+l"Merging weight"

	if ((index == 0)); then
		gmt psbasemap -P -R${region} -J${projection_remaining} \
			"${x_axis}" "${y_axis}" "${frame}" -X0.55i -Y8.7i -K \
			--FONT_TITLE=7p --MAP_TITLE_OFFSET=8p > "${remaining_ps_file}"
	elif ((index == 25)); then
		gmt psbasemap -R -J "${x_axis}" "${y_axis}" "${frame}" \
			-X-4.65i -Y-1.42i -O -K --FONT_TITLE=7p --MAP_TITLE_OFFSET=8p \
			>> "${remaining_ps_file}"
	elif ((index % 5 == 0)); then
		gmt psbasemap -R -J "${x_axis}" "${y_axis}" "${frame}" \
			-X-6.2i -Y-1.42i -O -K --FONT_TITLE=7p --MAP_TITLE_OFFSET=8p \
			>> "${remaining_ps_file}"
	else
		gmt psbasemap -R -J "${x_axis}" "${y_axis}" "${frame}" \
			-X1.55i -O -K --FONT_TITLE=7p --MAP_TITLE_OFFSET=8p \
			>> "${remaining_ps_file}"
	fi
	gmt psxy "${work_dir}/support_edges.txt" -R -J -W0.5p,gray65,- \
		-O -K >> "${remaining_ps_file}"
	if ((index + 1 == ${#remaining_windows[@]})); then
		gmt psxy "${work_dir}/${function}.txt" -i0,2 -R -J \
			-W1.5p,deepskyblue -O >> "${remaining_ps_file}"
	else
		gmt psxy "${work_dir}/${function}.txt" -i0,2 -R -J \
			-W1.5p,deepskyblue -O -K >> "${remaining_ps_file}"
	fi
done

gmt psconvert "${remaining_ps_file}" -A -Tf \
	-F"${script_dir}/ex07_window_functions_remaining"
gmt psconvert "${remaining_ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex07_window_functions_remaining"
