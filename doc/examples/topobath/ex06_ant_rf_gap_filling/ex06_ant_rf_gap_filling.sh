#!/usr/bin/env bash
#
# Fill Cascadia ANT+RF gaps, flatten it, and compare construction methods.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() {
	if [[ $1 == topobath && -n "${GQ_TOPOBATH_RUNNER:-}" ]]; then
		shift
		if [[ -z "${GQ_PLUGIN:-}" ]]; then
			echo "GQ_PLUGIN is required with GQ_TOPOBATH_RUNNER" >&2
			exit 1
		fi
		GQ_PLUGIN="${GQ_PLUGIN}" command "${GQ_TOPOBATH_RUNNER}" "$@"
	else
		command "${gmt_executable}" "$@"
	fi
}
plot_depth_label() {
	gmt pstext -R -J -F+cBR+f10p,Helvetica,black+jBR+t"0 km" \
		-D-0.08i/0.08i -Gwhite -C0.08c -N -O -K
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
data_dir="${script_dir}/../../data/cascadia"
prepare_script="${data_dir}/prepare_vs_slices.sh"
model_file="${data_dir}/Cascadia-ANT+RF-Delph2018.r0.1.nc"
relief_file="${data_dir}/cascadia_earth_relief_01m_g.nc"

if [[ ! -s "${model_file}" ]]; then
	GMT="${gmt_executable}" "${prepare_script}"
fi
if [[ ! -s "${relief_file}" ]]; then
	gmt grdcut @earth_relief_01m_g -R-130/-116/39/52 \
		-G"${relief_file}"
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-topobath-ex06-ant-rf.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white PS_MEDIA A3

region=-124.8/-120/40/49
increment=0.2
section_latitude=47
model="${model_file}?Vs+Zkm"
relief="${relief_file}?z+z-0.001+Zkm"
flattened="${work_dir}/flattened.nc"
pull="${work_dir}/pull.nc"
extend="${work_dir}/extend.nc"
linear="${work_dir}/linear.nc"
old_surface="${work_dir}/old_surface.nc"
classification="${work_dir}/classification.nc"

# Fill internal horizontal and vertical gaps, infer and write the existing
# surface, then shift it to zero depth. Retain enough depth for the subsequent
# pull/push operation.
gmt topobath "${model}" -Or+t -R${region} -I${increment} -T0/10/0.1 \
	-Hl -Sl+g -WVs/0+t0.01 -Dh -A0/0/1 \
	-Q"${old_surface}"+c"${classification}" -G"${flattened}"

# Apply the same local relief grid to the flattened model with each method.
gmt topobath "${flattened}?Vs" "${relief}" -Oa+t -Mp \
	-R${region} -I${increment} -T-5/2/0.1 -WVs/0+t0.01 \
	-Dh -A0/0/1 -G"${pull}"
gmt topobath "${flattened}?Vs" "${relief}" -Oa+t -Me \
	-R${region} -I${increment} -T-5/2/0.1 -WVs/0+t0.01 \
	-Dh -A0/0/1 -G"${extend}"
gmt topobath "${flattened}?Vs" "${relief}" -Oa+t -Ml \
	-R${region} -I${increment} -T-5/2/0.1 -WVs/0+t0.01 -LVs/0.5 \
	-Dh -A0/0/1 -G"${linear}"

# Extract zero-depth maps. The topographic outputs begin at -5 km, so zero
# depth is layer 50 at 0.1 km spacing.
gmt grdconvert "${flattened}?Vs[0]" "${work_dir}/flattened_map.nc"
for name in pull extend linear; do
	gmt grdconvert "${work_dir}/${name}.nc?Vs[50]" \
		"${work_dir}/${name}_map.nc"
done

# Extract latitude = 47 N sections and pad the flattened model above zero.
gmt grdcut "${model_file}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/original_section_native.nc"
gmt grdcut "${work_dir}/original_section_native.nc" \
	-R-124.9/-119.9/-5/2 -NNaN -G"${work_dir}/original_section_raw.nc"
gmt grdmath "${work_dir}/original_section_raw.nc" 0 NAN = \
	"${work_dir}/original_section.nc"

gmt grdcut "${flattened}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/flattened_section_native.nc"
gmt grdcut "${work_dir}/flattened_section_native.nc" \
	-R-124.9/-119.9/-5/2 -NNaN -G"${work_dir}/flattened_section.nc"
for name in pull extend linear; do
	gmt grdcut "${work_dir}/${name}.nc?Vs" -Ey${section_latitude} \
		-G"${work_dir}/${name}_section.nc"
done

# Surface profiles use the positive-down section coordinate.
awk -v latitude="${section_latitude}" 'BEGIN {
	for (i = 0; i < 25; i++) print -124.8 + 0.2 * i, latitude
}' > "${work_dir}/profile_points.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${old_surface}" | \
	awk '{print $1, $3}' > "${work_dir}/old_surface_profile.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${relief_file}" | \
	awk '{print $1, -0.001 * $3}' > "${work_dir}/new_surface_profile.txt"
printf '%s 0\n%s 0\n' -124.9 -119.9 > "${work_dir}/flat_surface_profile.txt"

# Verify that the extension methods produce different models.
gmt grdmath "${work_dir}/extend_section.nc" "${work_dir}/linear_section.nc" \
	SUB = "${work_dir}/method_difference.nc"
gmt grdinfo "${work_dir}/method_difference.nc" -C | \
	awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'

velocity_cpt="${work_dir}/velocity.cpt"
elevation_cpt="${work_dir}/elevation.cpt"
classification_cpt="${work_dir}/classification.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
gmt makecpt -Cdem2 -T0/4/0.25 -Z > "${elevation_cpt}"
cat > "${classification_cpt}" <<- EOF
	0 gray90 1 gray90
	1 seagreen 2 seagreen
	2 deepskyblue 3 deepskyblue
	B black
	F white
	N white
	EOF
gmt grdmath "${old_surface}" -1 MUL 0 MAX = "${work_dir}/old_elevation.nc"

map_projection=M3.1i
section_region=-124.9/-119.9/-5/2
section_projection=X3.1i/-1.55i
# GMT 6.5 scales colorbar fonts by bar length. These nominal sizes both
# render as 10p for the corresponding 2.7i and 6.7i colorbars.
short_colorbar_font=14.75p
wide_colorbar_font=9.36p

# Figure 1: inferred-surface diagnostics and flattening.
diagnostics_ps="${work_dir}/ex06_ant_rf_gap_filling_diagnostics.ps"
gmt grdimage "${work_dir}/old_elevation.nc" -P -R${region} \
	-J${map_projection} -C"${elevation_cpt}" -Bxa1f0.2 \
	-Bya2f1+l"Latitude" -BWSen+t"(a) Inferred elevation" \
	-nn -X0.7i -Y4.2i -K > "${diagnostics_ps}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${diagnostics_ps}"
printf '%s %s\n%s %s\n' -124.8 "${section_latitude}" -120 \
	"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
	-O -K >> "${diagnostics_ps}"
gmt psscale -R -J -C"${elevation_cpt}" \
	-DjBC+w2.7i/0.11i+h+o0/-0.88i -Bxa1f0.5+l"Elevation (km)" \
	--FONT_ANNOT_PRIMARY=${short_colorbar_font} \
	--FONT_LABEL=${short_colorbar_font} \
	-O -K >> "${diagnostics_ps}"

gmt grdimage "${classification}" -R -J -C"${classification_cpt}" \
	-Bxa1f0.2 -Bya2f1 -BwSen+t"(b) Inference class" \
	-nn -X3.6i -O -K >> "${diagnostics_ps}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${diagnostics_ps}"
printf '%s %s\n%s %s\n' -124.8 "${section_latitude}" -120 \
	"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
	-O -K >> "${diagnostics_ps}"
gmt psscale -R -J -C"${classification_cpt}" \
	-DjBC+w2.7i/0.11i+h+o0/-0.88i -Bxa1f1+l"Class" \
	--FONT_ANNOT_PRIMARY=${short_colorbar_font} \
	--FONT_LABEL=${short_colorbar_font} \
	-O -K >> "${diagnostics_ps}"

gmt grdimage "${work_dir}/original_section.nc" -R${section_region} \
	-J${section_projection} -C"${velocity_cpt}" -Bxa1f0.2+l"Longitude" \
	-Bya1f0.5+l"Depth (km)" -BWSen+t"(c) Original topography" \
	-fc -X-3.6i -Y-3.25i -O -K >> "${diagnostics_ps}"
gmt psxy "${work_dir}/old_surface_profile.txt" -R -J -W1.5p,black \
	-fc -O -K >> "${diagnostics_ps}"

gmt grdimage "${work_dir}/flattened_section.nc" -R -J \
	-C"${velocity_cpt}" -Bxa1f0.2+l"Longitude" -Bya1f0.5 \
	-BwSen+t"(d) Flattened" -fc -X3.6i -O -K >> "${diagnostics_ps}"
gmt psxy "${work_dir}/flat_surface_profile.txt" -R -J -W1.5p,black \
	-fc -O -K >> "${diagnostics_ps}"
gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-3.6i/-0.58i+w6.7i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=${wide_colorbar_font} \
	--FONT_LABEL=${wide_colorbar_font} \
	-O >> "${diagnostics_ps}"

gmt psconvert "${diagnostics_ps}" -A+m0.25i -Tf \
	-F"${script_dir}/ex06_ant_rf_gap_filling_diagnostics"
gmt psconvert "${diagnostics_ps}" -A+m0.25i -Tg -E300 \
	-F"${script_dir}/ex06_ant_rf_gap_filling_diagnostics"

# Figure 2: method comparison at zero depth and along latitude = 47 N.
methods_ps="${work_dir}/ex06_ant_rf_gap_filling_methods.ps"
map_names=(flattened pull extend linear)
map_titles=("Flattened" "Pull-up/push-down" "Constant extension" "Linear extension")
map_letters=(a b c d)

for index in 0 1 2 3; do
	name=${map_names[index]}
	title="(${map_letters[index]}) ${map_titles[index]}"
	y_axis=-Bya2f1
	if ((index == 0)); then
		y_axis=-Bya2f1+l"Latitude"
		gmt grdimage "${work_dir}/${name}_map.nc" -P -R${region} \
			-JM1.55i -C"${velocity_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BWSen+t${title}" -X0.4i -Y3.9i \
			-K > "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_map.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -X1.95i \
			-O -K >> "${methods_ps}"
	fi
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 \
		-O -K >> "${methods_ps}"
	printf '%s %s\n%s %s\n' -124.8 "${section_latitude}" -120 \
		"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${methods_ps}"
	plot_depth_label >> "${methods_ps}"
done

section_names=(flattened pull extend linear)
section_titles=("Flattened" "Pull-up/push-down" "Constant extension" "Linear extension")
section_letters=(e f g h)
for index in 0 1 2 3; do
	name=${section_names[index]}
	title="(${section_letters[index]}) ${section_titles[index]}"
	y_axis=-Bya1f0.5
	profile="${work_dir}/new_surface_profile.txt"
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Depth (km)"
		profile="${work_dir}/flat_surface_profile.txt"
		gmt grdimage "${work_dir}/${name}_section.nc" \
			-R${section_region} -JX1.55i/-1.45i -C"${velocity_cpt}" \
			-Bxa2f0.2+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
			-fc -X-5.85i -Y-2.55i -O -K >> "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_section.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -fc -X1.95i \
			-O -K >> "${methods_ps}"
	fi
	gmt psxy "${profile}" -R -J -W1.5p,black -fc \
		-O -K >> "${methods_ps}"
done

gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-5.85i/-0.78i+w7.4i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=10p --FONT_LABEL=10p -O >> "${methods_ps}"

gmt psconvert "${methods_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex06_ant_rf_gap_filling_methods"
gmt psconvert "${methods_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex06_ant_rf_gap_filling_methods"
