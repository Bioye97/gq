#!/usr/bin/env bash
#
# Compare symmetric and asymmetric taper ratios and mixed X/Y/Z windows.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex10-asymmetric.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 10p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
zrange=0/100/1
horizontal_projection=X2.15i/2.15i
vertical_projection=X2.15i/-2.15i
primary="${work_dir}/primary.nc"
secondary="${work_dir}/secondary.nc"
horizontal_support="${work_dir}/horizontal_support.txt"
vertical_support="${work_dir}/vertical_support.txt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=11.45p

# Constant primary and secondary volumes make value checks unambiguous.
for z in 15 85; do
	gmt grdmath -R15/85/15/85 -I${increment} 8 = \
		"${work_dir}/primary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/primary_*.nc -Z15/85/70 -G"${primary}"
for z in 0 100; do
	gmt grdmath -R${region} -I${increment} 2 = \
		"${work_dir}/secondary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/secondary_*.nc -Z0/100/100 -G"${secondary}"

cat > "${horizontal_support}" <<- EOF
	15 15
	85 15
	85 85
	15 85
	15 15
	EOF
cat > "${vertical_support}" <<- EOF
	15 15
	85 15
	85 85
	15 85
	15 15
	EOF

make_merge() {
	local name=$1
	local functions=$2
	local ratios=$3
	local mergefile="${work_dir}/${name}.merge3d"
	local output="${work_dir}/${name}.nc"
	cat > "${mergefile}" <<- EOF
		${primary} ${secondary} - - ${functions} ${ratios}
		${secondary} - - - - -
		EOF
	gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
		-W -G"${output}"
}

# First vary taper symmetry, then retain all six asymmetric ratios while
# changing the directional functions.
make_merge symmetric cosine/cosine/cosine 0.25
make_merge asymmetric_x cosine/cosine/cosine \
	0.05/0.40/0.25/0.25/0.25/0.25
make_merge asymmetric_xyz cosine/cosine/cosine \
	0.05/0.40/0.15/0.35/0.10/0.45
make_merge trapezoid_gaussian_sine trapezoid/gaussian/sine \
	0.05/0.40/0.15/0.35/0.10/0.45
make_merge planck_welch_kaiser plancktaper/welch/kaiser \
	0.05/0.40/0.15/0.35/0.10/0.45
make_merge hamming_logistic_bohman hamming/logistic/bohman \
	0.05/0.40/0.15/0.35/0.10/0.45

outputs=(
	symmetric asymmetric_x asymmetric_xyz
	trapezoid_gaussian_sine planck_welch_kaiser hamming_logistic_bohman
)
titles=(
	"Symmetric cosine" "Asymmetric x" "Asymmetric x, y, and z"
	"Trapezoid / Gaussian / Sine"
	"Planck taper / Welch / Kaiser"
	"Hamming / Logistic / Bohman"
)

# Extract center sections and verify the constant-field weighted relation.
for name in "${outputs[@]}"; do
	output="${work_dir}/${name}.nc"
	gmt grdconvert "${output}?cube[50]" "${work_dir}/${name}_horizontal.nc"
	gmt grdconvert "${output}?weight[50]" \
		"${work_dir}/${name}_weight_horizontal.nc"
	gmt grdcut "${output}?cube" -Ey50 -G"${work_dir}/${name}_vertical.nc"
	gmt grdcut "${output}?weight" -Ey50 \
		-G"${work_dir}/${name}_weight_vertical.nc"

	for view in horizontal vertical; do
		gmt grdmath "${work_dir}/${name}_${view}.nc" \
			"${work_dir}/${name}_weight_${view}.nc" 6 MUL 2 ADD SUB = \
			"${work_dir}/${name}_${view}_difference.nc"
		gmt grdinfo "${work_dir}/${name}_${view}_difference.nc" -C | \
			awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
		gmt grdinfo "${work_dir}/${name}_weight_${view}.nc" -C | \
			awk '$6 < -1e-6 || $7 > 1.000001 {exit 1}'
	done
done

# The baseline is symmetric in x, y, and z.
printf "20 50\n80 50\n50 20\n50 80\n" | \
	gmt grdtrack -G"${work_dir}/symmetric_weight_horizontal.nc" > \
	"${work_dir}/symmetric_horizontal_samples.txt"
printf "20 50\n80 50\n50 20\n50 80\n" | \
	gmt grdtrack -G"${work_dir}/symmetric_weight_vertical.nc" > \
	"${work_dir}/symmetric_vertical_samples.txt"
for samples in symmetric_horizontal_samples symmetric_vertical_samples; do
	awk 'NR == 1 {low_x = $3}
		 NR == 2 && (($3 - low_x > 1e-6) || (low_x - $3 > 1e-6)) {exit 1}
		 NR == 3 {low_y = $3}
		 NR == 4 && (($3 - low_y > 1e-6) || (low_y - $3 > 1e-6)) {exit 1}' \
		"${work_dir}/${samples}.txt"
done

# Smaller west, south, and upper ratios produce stronger weights at equal
# distances from those boundaries than at the east, north, and lower sides.
printf "20 50\n80 50\n50 20\n50 80\n" | \
	gmt grdtrack -G"${work_dir}/asymmetric_xyz_weight_horizontal.nc" > \
	"${work_dir}/asymmetric_horizontal_samples.txt"
printf "20 50\n80 50\n50 20\n50 80\n" | \
	gmt grdtrack -G"${work_dir}/asymmetric_xyz_weight_vertical.nc" > \
	"${work_dir}/asymmetric_vertical_samples.txt"
awk 'NR == 1 {west = $3}
	 NR == 2 && west <= $3 {exit 1}
	 NR == 3 {south = $3}
	 NR == 4 && south <= $3 {exit 1}' \
	"${work_dir}/asymmetric_horizontal_samples.txt"
awk 'NR == 1 {west = $3}
	 NR == 2 && west <= $3 {exit 1}
	 NR == 3 {upper = $3}
	 NR == 4 && upper <= $3 {exit 1}' \
	"${work_dir}/asymmetric_vertical_samples.txt"

# Each mixed X/Y/Z function triplet must differ from all-cosine weights in
# both section directions.
for name in trapezoid_gaussian_sine planck_welch_kaiser \
	hamming_logistic_bohman; do
	for view in horizontal vertical; do
		gmt grdmath "${work_dir}/${name}_weight_${view}.nc" \
			"${work_dir}/asymmetric_xyz_weight_${view}.nc" SUB ABS = \
			"${work_dir}/${name}_${view}_window_difference.nc"
		gmt grdinfo "${work_dir}/${name}_${view}_window_difference.nc" -C | \
			awk '$7 <= 0.01 {exit 1}'
	done
done

gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

plot_view() {
	local view=$1
	local projection=$2
	local support=$3
	local y_label=$4
	local section_label=$5
	local output_name=$6
	local ps_file="${work_dir}/${output_name}.ps"

	for ((index = 0; index < ${#outputs[@]}; index++)); do
		name=${outputs[index]}
		title="(${letters[index]}) ${titles[index]}: ${section_label}"
		y_axis=-Byf10
		if ((index == 0 || index == 3)); then
			y_axis=-Bya20f10+l"${y_label}"
		fi
		if ((index == 0)); then
			gmt grdimage "${work_dir}/${name}_weight_${view}.nc" -P \
				-R${region} -J${projection} -C"${weight_cpt}" \
				-Bxa20f10+l"X" "${y_axis}" "-BWSen+t${title}" \
				-X0.45i -Y4.2i -K > "${ps_file}"
		elif ((index == 3)); then
			gmt grdimage "${work_dir}/${name}_weight_${view}.nc" \
				-R -J -C"${weight_cpt}" -Bxa20f10+l"X" "${y_axis}" \
				"-BWSen+t${title}" -X-5.4i -Y-3.1i -O -K >> "${ps_file}"
		else
			gmt grdimage "${work_dir}/${name}_weight_${view}.nc" \
				-R -J -C"${weight_cpt}" -Bxa20f10+l"X" "${y_axis}" \
				"-BWSen+t${title}" -X2.7i -O -K >> "${ps_file}"
		fi
		gmt psxy "${support}" -R -J -L -W1.5p,orangered,- \
			-O -K >> "${ps_file}"
	done

	gmt psscale -R -J -C"${weight_cpt}" \
		-DjBC+w4.5i/0.12i+h+o0/-1.0i \
		-Bxa0.2f0.1+l"Merging weight" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-X-2.7i -O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tf -F"${script_dir}/${output_name}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/${output_name}"
}

letters=(a b c d e f)
plot_view horizontal "${horizontal_projection}" "${horizontal_support}" \
	Y "z = 50" ex10_asymmetric_windows_horizontal
plot_view vertical "${vertical_projection}" "${vertical_support}" \
	Z "y = 50" ex10_asymmetric_windows_vertical
