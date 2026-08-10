#!/usr/bin/env bash
#
# Compare all 53 BLEND window functions through their 3-D merge3d weights.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex09-windows.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 7p FONT_LABEL 8p FONT_TITLE 8p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 10p COLOR_NAN white

region=0/100/0/100
increment=2
zrange=0/100/2
horizontal_projection=X1.45i/1.45i
vertical_projection=X1.45i/-1.45i
horizontal_projection_remaining=X1.35i/1.35i
vertical_projection_remaining=X1.35i/-1.35i
primary="${work_dir}/primary.nc"
secondary="${work_dir}/secondary.nc"
horizontal_support="${work_dir}/horizontal_support.txt"
vertical_support="${work_dir}/vertical_support.txt"
weight_cpt="${work_dir}/weights.cpt"
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

# The primary fills x/y = 16/84 and z = 20/80 inside the output volume.
for z in 20 80; do
	gmt grdmath -R16/84/16/84 -I${increment} 8 = \
		"${work_dir}/primary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/primary_*.nc -Z20/80/60 -G"${primary}"
for z in 0 100; do
	gmt grdmath -R${region} -I${increment} 2 = \
		"${work_dir}/secondary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/secondary_*.nc -Z0/100/100 -G"${secondary}"

cat > "${horizontal_support}" <<- EOF
	16 16
	84 16
	84 84
	16 84
	16 16
	EOF
cat > "${vertical_support}" <<- EOF
	16 20
	84 20
	84 80
	16 80
	16 20
	EOF

# Generate one symmetric 3-D weight for every unique window implementation.
for function in "${all_windows[@]}"; do
	mergefile="${work_dir}/${function}.merge3d"
	output="${work_dir}/${function}.nc"
	cat > "${mergefile}" <<- EOF
		${primary} ${secondary} - - ${function}/${function}/${function} 0.49
		${secondary} - - - - -
		EOF
	gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
		-W+o -G"${output}"

	# Preserve perpendicular center sections and discard the temporary volume.
	gmt grdconvert "${output}?weight[25]" \
		"${work_dir}/${function}_horizontal.nc"
	gmt grdcut "${output}?weight" -Ey50 \
		-G"${work_dir}/${function}_vertical.nc"

	for view in horizontal vertical; do
		gmt grdmath "${work_dir}/${function}_${view}.nc" ISNAN = \
			"${work_dir}/${function}_${view}_missing.nc"
		gmt grdinfo "${work_dir}/${function}_${view}_missing.nc" -C | \
			awk '$7 != 0 {exit 1}'
		gmt grdinfo "${work_dir}/${function}_${view}.nc" -C | \
			awk '$6 < -1e-6 || $7 > 1.000001 {exit 1}'
	done
	rm -f "${output}"
done

gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

plot_group() {
	local view=$1
	local group=$2
	local projection=$3
	local support=$4
	local output_name=$5
	local ps_file="${work_dir}/${output_name}.ps"
	local panel_windows panel_labels number_offset start_y row_shift column_shift

	if [[ "${group}" == main ]]; then
		panel_windows=("${windows[@]}")
		panel_labels=("${labels[@]}")
		number_offset=0
		start_y=8.4i
		row_shift=-1.9i
		column_shift=1.65i
	else
		panel_windows=("${remaining_windows[@]}")
		panel_labels=("${remaining_labels[@]}")
		number_offset=${#windows[@]}
		start_y=9.3i
		row_shift=-1.69i
		column_shift=1.62i
	fi

	for ((index = 0; index < ${#panel_windows[@]}; index++)); do
		function=${panel_windows[index]}
		title="($((index + number_offset + 1))) ${panel_labels[index]}"
		frame="-BWSen+t${title}"
		font_options=(--FONT_TITLE=8p --MAP_TITLE_OFFSET=10p)
		if [[ "${group}" == remaining ]]; then
			font_options=(--FONT_TITLE=7p --MAP_TITLE_OFFSET=8p)
		fi

		if ((index == 0)); then
			gmt grdimage "${work_dir}/${function}_${view}.nc" -P \
				-R${region} -J${projection} -C"${weight_cpt}" \
				-Bxf25 -Byf25 "${frame}" -X0.25i -Y${start_y} -K \
				"${font_options[@]}" > "${ps_file}"
		elif [[ "${group}" == remaining ]] && ((index == 25)); then
			gmt grdimage "${work_dir}/${function}_${view}.nc" \
				-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
				-X-4.86i -Y${row_shift} -O -K "${font_options[@]}" \
				>> "${ps_file}"
		elif ((index % 5 == 0)); then
			local back_shift=-6.6i
			if [[ "${group}" == remaining ]]; then
				back_shift=-6.48i
			fi
			gmt grdimage "${work_dir}/${function}_${view}.nc" \
				-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
				-X${back_shift} -Y${row_shift} -O -K "${font_options[@]}" \
				>> "${ps_file}"
		else
			gmt grdimage "${work_dir}/${function}_${view}.nc" \
				-R -J -C"${weight_cpt}" -Bxf25 -Byf25 "${frame}" \
				-X${column_shift} -O -K "${font_options[@]}" \
				>> "${ps_file}"
		fi
		gmt psxy "${support}" -R -J -L -W1.5p,orangered,- \
			-O -K >> "${ps_file}"
	done

	local scale_shift=-3.3i
	local scale_offset=-0.65i
	if [[ "${group}" == remaining ]]; then
		scale_shift=-1.62i
		scale_offset=-0.7i
	fi
	gmt psscale -R -J -C"${weight_cpt}" \
		-DjBC+w5.5i/0.12i+h+o0/${scale_offset} \
		-Bxa0.2f0.1+l"Merging weight" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-X${scale_shift} -O >> "${ps_file}"

	gmt psconvert "${ps_file}" -A+m0.1i -Tf -F"${script_dir}/${output_name}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/${output_name}"
}

plot_group horizontal main "${horizontal_projection}" \
	"${horizontal_support}" ex09_window_functions_horizontal
plot_group vertical main "${vertical_projection}" \
	"${vertical_support}" ex09_window_functions_vertical
plot_group horizontal remaining "${horizontal_projection_remaining}" \
	"${horizontal_support}" ex09_window_functions_horizontal_remaining
plot_group vertical remaining "${vertical_projection_remaining}" \
	"${vertical_support}" ex09_window_functions_vertical_remaining
