#!/usr/bin/env bash
#
# Flatten and replace the existing WUS324 topography and bathymetry.

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
model_file="${data_dir}/WUS324-Casc-CVM.r0.0-n4.nc"
original_section_file="${data_dir}/WUS324-Casc-Vs-lat47.nc"
relief_file="${data_dir}/cascadia_earth_relief_01m_g.nc"

if [[ ! -s "${model_file}" || ! -s "${original_section_file}" ]]; then
	GMT="${gmt_executable}" "${prepare_script}"
fi
if [[ ! -s "${relief_file}" ]]; then
	gmt grdcut @earth_relief_01m_g -R-130/-116/39/52 \
		-G"${relief_file}"
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-topobath-ex04-wus324.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-126/-121/42/50
increment=0.125
section_latitude=47
model="${model_file}?Vs+Zkm"
relief="${relief_file}?z+z-0.001+Zkm"
flatten="${work_dir}/flatten.nc"
keep="${work_dir}/keep.nc"
remove_bathymetry="${work_dir}/remove_bathymetry.nc"
pull="${work_dir}/pull.nc"
extend="${work_dir}/extend.nc"
linear="${work_dir}/linear.nc"
old_surface="${work_dir}/old_surface.nc"
classification="${work_dir}/classification.nc"

# Remove the complete original surface or flatten only land while retaining
# the existing ocean columns.
gmt topobath "${model}" -Or -R${region} -I${increment} -T0/2/0.1 \
	-WVs/0+t0.01 -Dh -A0/0/1 \
	-Q"${old_surface}"+c"${classification}" -G"${flatten}"
gmt topobath "${model}" -Or+t -R${region} -I${increment} -T0/2/0.1 \
	-E"${old_surface}" -Dh -A0/0/1 -G"${keep}"
gmt topobath "${model}" -Or+b -R${region} -I${increment} -T-5/2/0.1 \
	-E"${old_surface}" -Dh -A0/0/1 -G"${remove_bathymetry}"

# Replace the inferred WUS324 surface with the local relief grid.
gmt topobath "${model}" "${relief}" -Ox -Mp -R${region} -I${increment} \
	-T-5/2/0.1 -E"${old_surface}" -WVs/0+t0.01 \
	-Dh -A0/0/1 -G"${pull}"
gmt topobath "${model}" "${relief}" -Ox -Me -R${region} -I${increment} \
	-T-5/2/0.1 -E"${old_surface}" -WVs/0+t0.01 \
	-Dh -A0/0/1 -G"${extend}"
gmt topobath "${model}" "${relief}" -Ox -Ml -R${region} -I${increment} \
	-T-5/2/0.1 -E"${old_surface}" -WVs/0+t0.01 -LVs/0.5 \
	-Dh -A0/0/1 -G"${linear}"

# The WUS324 z axis starts at -4 km, making sea level source layer 4.
gmt grdconvert "${model_file}?Vs[4]" "${work_dir}/original_map_full.nc" -Vq
gmt grdcut "${work_dir}/original_map_full.nc" -R${region} \
	-G"${work_dir}/original_map.nc" -Vq
for name in flatten keep; do
	gmt grdconvert "${work_dir}/${name}.nc?Vs[0]" \
		"${work_dir}/${name}_map.nc" -Vq
done
gmt grdconvert "${remove_bathymetry}?Vs[50]" \
	"${work_dir}/remove_bathymetry_map.nc" -Vq
for name in pull extend linear; do
	gmt grdconvert "${work_dir}/${name}.nc?Vs[50]" \
		"${work_dir}/${name}_map.nc" -Vq
done

gmt grdcut "${original_section_file}" -R-126/-121/-5/2 \
	-G"${work_dir}/original_section.nc" -Vq
for name in flatten keep remove_bathymetry pull extend linear; do
	gmt grdcut "${work_dir}/${name}.nc?Vs" -Ey${section_latitude} \
		-G"${work_dir}/${name}_section.nc" -Vq
done

# Sample the inferred, retained, flat, and replacement surfaces.
awk -v latitude="${section_latitude}" 'BEGIN {
	for (i = 0; i <= 40; i++) print -126 + 0.125 * i, latitude
}' > "${work_dir}/profile_points.txt"
gmt grdtrack "${work_dir}/profile_points.txt" \
	-G"${old_surface}" -G"${classification}" | \
	awk '{print $1, $3}' > "${work_dir}/old_surface_profile.txt"
gmt grdtrack "${work_dir}/profile_points.txt" \
	-G"${old_surface}" -G"${classification}" | \
	awk '{print $1, ($4 == 2 ? $3 : 0)}' \
	> "${work_dir}/keep_surface_profile.txt"
gmt grdtrack "${work_dir}/profile_points.txt" \
	-G"${old_surface}" -G"${classification}" | \
	awk '{print $1, ($4 == 2 ? 0 : $3)}' \
	> "${work_dir}/remove_bathymetry_surface_profile.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${relief_file}" | \
	awk '{print $1, -0.001 * $3}' > "${work_dir}/new_surface_profile.txt"
printf '%s 0\n%s 0\n' -126 -121 > "${work_dir}/flat_surface_profile.txt"

gmt grdmath "${work_dir}/extend_section.nc" \
	"${work_dir}/linear_section.nc" SUB = \
	"${work_dir}/method_difference.nc"
gmt grdinfo "${work_dir}/method_difference.nc" -C | \
	awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'

velocity_cpt="${work_dir}/velocity.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
section_region=-126/-121/-5/2

# Figure 1: remove topography, bathymetry, or both.
flatten_ps="${work_dir}/ex04_wus324_flattening.ps"
flatten_names=(original flatten keep remove_bathymetry)
flatten_titles=("Original" "Remove both" "Remove topo. only" "Remove bathy. only")
flatten_letters=(a b c d)
for index in 0 1 2 3; do
	name=${flatten_names[index]}
	title="(${flatten_letters[index]}) ${flatten_titles[index]}"
	y_axis=-Bya2f1
	if ((index == 0)); then
		y_axis=-Bya2f1+l"Latitude"
		gmt grdimage "${work_dir}/${name}_map.nc" -P -R${region} \
			-JM1.65i -C"${velocity_cpt}" -Bxa2f0.25+l"Longitude" \
			"${y_axis}" "-BWSen+t${title}" -X0.5i -Y3.8i \
			-K > "${flatten_ps}"
	else
		gmt grdimage "${work_dir}/${name}_map.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.25+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -X1.9i \
			-O -K >> "${flatten_ps}"
	fi
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 \
		-O -K >> "${flatten_ps}"
	printf '%s %s\n%s %s\n' -126 "${section_latitude}" -121 \
		"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${flatten_ps}"
	plot_depth_label >> "${flatten_ps}"
done

flatten_section_letters=(e f g h)
for index in 0 1 2 3; do
	name=${flatten_names[index]}
	title="(${flatten_section_letters[index]}) ${flatten_titles[index]}"
	y_axis=-Bya1f0.5
	profile="${work_dir}/flat_surface_profile.txt"
	if [[ ${name} == original ]]; then profile="${work_dir}/old_surface_profile.txt"; fi
	if [[ ${name} == keep ]]; then profile="${work_dir}/keep_surface_profile.txt"; fi
	if [[ ${name} == remove_bathymetry ]]; then
		profile="${work_dir}/remove_bathymetry_surface_profile.txt"
	fi
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Depth (km)"
		gmt grdimage "${work_dir}/${name}_section.nc" \
			-R${section_region} -JX1.65i/-1.55i -C"${velocity_cpt}" \
			-Bxa2f0.25+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
			-fc -X-5.7i -Y-2.55i -O -K >> "${flatten_ps}"
	else
		gmt grdimage "${work_dir}/${name}_section.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.25+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -fc -X1.9i \
			-O -K >> "${flatten_ps}"
	fi
	gmt psxy "${profile}" -R -J -W1.5p,black -fc \
		-O -K >> "${flatten_ps}"
done

gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-5.7i/-0.78i+w7.35i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=10p --FONT_LABEL=10p -O >> "${flatten_ps}"
gmt psconvert "${flatten_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex04_wus324_flattening"
gmt psconvert "${flatten_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex04_wus324_flattening"

# Figure 2: replace the original surface with the three construction methods.
methods_ps="${work_dir}/ex04_wus324_methods.ps"
method_names=(original pull extend linear)
method_titles=("Original" "Pull-up/push-down" "Constant extension" "Linear extension")
method_letters=(a b c d)
for index in 0 1 2 3; do
	name=${method_names[index]}
	title="(${method_letters[index]}) ${method_titles[index]}"
	y_axis=-Bya2f1
	if ((index == 0)); then
		y_axis=-Bya2f1+l"Latitude"
		gmt grdimage "${work_dir}/${name}_map.nc" -P -R${region} \
			-JM1.65i -C"${velocity_cpt}" -Bxa2f0.25+l"Longitude" \
			"${y_axis}" "-BWSen+t${title}" -X0.4i -Y3.8i \
			-K > "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_map.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.25+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -X2i \
			-O -K >> "${methods_ps}"
	fi
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 \
		-O -K >> "${methods_ps}"
	printf '%s %s\n%s %s\n' -126 "${section_latitude}" -121 \
		"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${methods_ps}"
	plot_depth_label >> "${methods_ps}"
done

method_section_letters=(e f g h)
for index in 0 1 2 3; do
	name=${method_names[index]}
	title="(${method_section_letters[index]}) ${method_titles[index]}"
	y_axis=-Bya1f0.5
	profile="${work_dir}/new_surface_profile.txt"
	if [[ ${name} == original ]]; then profile="${work_dir}/old_surface_profile.txt"; fi
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Depth (km)"
		gmt grdimage "${work_dir}/${name}_section.nc" \
			-R${section_region} -JX1.65i/-1.55i -C"${velocity_cpt}" \
			-Bxa2f0.25+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
			-fc -X-6i -Y-2.55i -O -K >> "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_section.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.25+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -fc -X2i \
			-O -K >> "${methods_ps}"
	fi
	gmt psxy "${profile}" -R -J -W1.5p,black -fc \
		-O -K >> "${methods_ps}"
done

gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-6i/-0.78i+w7.65i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=10p --FONT_LABEL=10p -O >> "${methods_ps}"
gmt psconvert "${methods_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex04_wus324_methods"
gmt psconvert "${methods_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex04_wus324_methods"
