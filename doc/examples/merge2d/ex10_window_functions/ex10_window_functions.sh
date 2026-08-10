#!/usr/bin/env bash
#
# Compare 25 BLEND window functions through their 2-D merge2d weights.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex10-windows.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 7p FONT_LABEL 8p FONT_TITLE 8p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 10p COLOR_NAN white

region=0/100/0/100
increment=1
projection=X1.45i/1.45i
projection_remaining=X1.35i/1.35i
primary="${work_dir}/primary.nc"
secondary="${work_dir}/secondary.nc"
support="${work_dir}/support.txt"
weight_cpt="${work_dir}/weights.cpt"
ps_file="${work_dir}/ex10_window_functions.ps"
remaining_ps_file="${work_dir}/ex10_window_functions_remaining.ps"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=10.4p

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

gmt grdmath -R15/85/15/85 -I${increment} 8 = "${primary}"
gmt grdmath -R${region} -I${increment} 2 = "${secondary}"
printf "15 15\n85 15\n85 85\n15 85\n" > "${support}"

# Generate the same symmetric 2-D support with all 53 unique window functions.
for function in "${all_windows[@]}"; do
	mergefile="${work_dir}/${function}.merge2d"
	output="${work_dir}/${function}.nc"
	cat > "${mergefile}" <<- EOF
		${primary} ${secondary} - ${function}/${function} 0.49
		${secondary} - - - -
		EOF
	gmt merge2d "${mergefile}" -R${region} -I${increment} -W -G"${output}"

	# Every weight grid must be complete and remain within the unit interval.
	gmt grdmath "${output}?weight" ISNAN = "${work_dir}/${function}_missing.nc"
	gmt grdinfo "${work_dir}/${function}_missing.nc" -C | \
		awk '$7 != 0 {exit 1}'
	gmt grdinfo "${output}?weight" -C | \
		awk '$6 < -1e-6 || $7 > 1.000001 {exit 1}'
done

gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

# Plot five columns by five rows with one shared weight scale.
for ((index = 0; index < ${#windows[@]}; index++)); do
	function=${windows[index]}
	title="($((index + 1))) ${labels[index]}"
	frame="-BWSen+t${title}"
	if ((index == 0)); then
		gmt grdimage "${work_dir}/${function}.nc?weight" -P \
			-R${region} -J${projection} -C"${weight_cpt}" \
			-Bxf25 -Byf25 "${frame}" -X0.25i -Y8.4i -K > "${ps_file}"
	elif ((index % 5 == 0)); then
		gmt grdimage "${work_dir}/${function}.nc?weight" \
			-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
			-X-6.6i -Y-1.9i -O -K >> "${ps_file}"
	else
		gmt grdimage "${work_dir}/${function}.nc?weight" \
			-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
			-X1.65i -O -K >> "${ps_file}"
	fi
	gmt psxy "${support}" -R -J -L -W1.5p,orangered,- \
		-O -K >> "${ps_file}"
done

gmt psscale -R -J -C"${weight_cpt}" -DjBC+w5.5i/0.12i+h+o0/-0.65i \
	-Bxa0.2f0.1+l"Merging weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -X-3.3i -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex10_window_functions"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex10_window_functions"

# Plot the remaining 28 functions in five columns, centering the final row.
for ((index = 0; index < ${#remaining_windows[@]}; index++)); do
	function=${remaining_windows[index]}
	title="($((index + ${#windows[@]} + 1))) ${remaining_labels[index]}"
	frame="-BWSen+t${title}"
	if ((index == 0)); then
		gmt grdimage "${work_dir}/${function}.nc?weight" -P \
			-R${region} -J${projection_remaining} -C"${weight_cpt}" \
			-Bxf25 -Byf25 "${frame}" -X0.25i -Y9.3i -K \
			--FONT_TITLE=7p --MAP_TITLE_OFFSET=8p > "${remaining_ps_file}"
	elif ((index == 25)); then
		gmt grdimage "${work_dir}/${function}.nc?weight" \
			-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
			-X-4.86i -Y-1.69i -O -K --FONT_TITLE=7p --MAP_TITLE_OFFSET=8p \
			>> "${remaining_ps_file}"
	elif ((index % 5 == 0)); then
		gmt grdimage "${work_dir}/${function}.nc?weight" \
			-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
			-X-6.48i -Y-1.69i -O -K --FONT_TITLE=7p --MAP_TITLE_OFFSET=8p \
			>> "${remaining_ps_file}"
	else
		gmt grdimage "${work_dir}/${function}.nc?weight" \
			-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
			-X1.62i -O -K --FONT_TITLE=7p --MAP_TITLE_OFFSET=8p \
			>> "${remaining_ps_file}"
	fi
	gmt psxy "${support}" -R -J -L -W1.5p,orangered,- \
		-O -K >> "${remaining_ps_file}"
done

gmt psscale -R -J -C"${weight_cpt}" -DjBC+w5.5i/0.12i+h+o0/-0.7i \
	-Bxa0.2f0.1+l"Merging weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -X-1.62i -O >> "${remaining_ps_file}"

gmt psconvert "${remaining_ps_file}" -A -Tf \
	-F"${script_dir}/ex10_window_functions_remaining"
gmt psconvert "${remaining_ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex10_window_functions_remaining"
