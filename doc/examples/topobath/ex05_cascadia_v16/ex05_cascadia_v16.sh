#!/usr/bin/env bash
#
# Flatten and replace the Cascadia v1.6 bathymetry.

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
model_file="${data_dir}/casc1.6-velmdl.r1.0-n4.nc"
relief_file="${data_dir}/cascadia_earth_relief_01m_g.nc"

if [[ ! -s "${model_file}" ]]; then
	GMT="${gmt_executable}" "${prepare_script}"
fi
if [[ ! -s "${relief_file}" ]]; then
	gmt grdcut @earth_relief_01m_g -R-130/-116/39/52 \
		-G"${relief_file}"
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-topobath-ex05-casc16.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region_m=250000/640000/4900000/5400000
region_km=250/640/4900/5400
ancillary_region_m=240000/650000/4890000/5410000
increment_m=10000
section_northing_m=5200000
section_northing_km=5200
staged_model="${work_dir}/cascadia_v16_upper5km.nc"
relief_utm="${work_dir}/relief_utm.nc"
landmask_geo="${work_dir}/landmask_geo.nc"
landmask_utm="${work_dir}/landmask_utm.nc"
flatten="${work_dir}/flatten.nc"
replace_bathy="${work_dir}/replace_bathy.nc"
pull="${work_dir}/pull.nc"
extend="${work_dir}/extend.nc"
linear="${work_dir}/linear.nc"
old_surface="${work_dir}/old_surface.nc"
classification="${work_dir}/classification.nc"

# Stage eleven 500 m layers on a small 10 km lattice. This prevents topobath
# from loading the dense native cube before applying the example region.
layers=()
for level in $(seq 0 10); do
	layer="${work_dir}/layer_${level}.nc"
	gmt grdsample "${model_file}?Vs[${level}]+s0.001" \
		-R${region_m} -I${increment_m} -rg -nl+c -G"${layer}" -Vq
	layers+=("${layer}")
done
gmt grdinterpolate "${layers[@]}" -Z0/5/0.5 -G"${staged_model}" \
	-D+vVs+zkm+d"km/s" -Vq

# Project the relief and wet-region mask to a one-cell-padded UTM grid so
# interpolation remains defined at every edge of the model subset.
gmt grdproject "${relief_file}" -Ju10N/1:1 -C -Fe \
	-R${ancillary_region_m}+ue -D${increment_m} -nl+c -G"${relief_utm}"
gmt grdlandmask -R-130/-116/39/52 -I1m -Dh -A0/0/1 \
	-N0/1/1/1/1 -G"${landmask_geo}"
gmt grdproject "${landmask_geo}" -Ju10N/1:1 -C -Fe \
	-R${ancillary_region_m}+ue -D${increment_m} -nn -G"${landmask_utm}"

model="${staged_model}?Vs"
relief="${relief_utm}?z+v-0.001+Vkm"

# Remove the existing bathymetry. Then add land topography with each
# construction method while retaining the original ocean columns.
gmt topobath "${model}" -Or+b -R${region_m} -I${increment_m} \
	-T0/2/0.1 -WVs/0+t0.01 -K"${landmask_utm}" \
	-Q"${old_surface}"+c"${classification}" -G"${flatten}"
gmt topobath "${model}" "${relief}" -Ox+b -Mp \
	-R${region_m} -I${increment_m} -T-5/2/0.1 \
	-E"${old_surface}" -WVs/0+t0.01 -K"${landmask_utm}" \
	-G"${replace_bathy}"
gmt topobath "${model}" "${relief}" -Oa+t -Mp -R${region_m} -I${increment_m} \
	-T-5/2/0.1 -E"${old_surface}" \
	-K"${landmask_utm}" -G"${pull}"
gmt topobath "${model}" "${relief}" -Oa+t -Me -R${region_m} -I${increment_m} \
	-T-5/2/0.1 -E"${old_surface}" \
	-K"${landmask_utm}" -G"${extend}"
gmt topobath "${model}" "${relief}" -Oa+t -Ml -R${region_m} -I${increment_m} \
	-T-5/2/0.1 -E"${old_surface}" -K"${landmask_utm}" \
	-LVs/0.5 -G"${linear}"

# Extract zero-depth maps and the vertical section, then express horizontal
# coordinates in kilometers for plotting.
gmt grdconvert "${staged_model}?Vs[0]" "${work_dir}/original_map.nc" -Vq
gmt grdconvert "${flatten}?Vs[0]" "${work_dir}/flatten_map.nc" -Vq
gmt grdconvert "${replace_bathy}?Vs[50]" \
	"${work_dir}/replace_bathy_map.nc" -Vq
for name in pull extend linear; do
	gmt grdconvert "${work_dir}/${name}.nc?Vs[50]" \
		"${work_dir}/${name}_map.nc" -Vq
done
for name in original flatten replace_bathy pull extend linear; do
	gmt grdedit "${work_dir}/${name}_map.nc" -R${region_km} -Vq
done

gmt grdcut "${staged_model}?Vs" -Ey${section_northing_m} \
	-G"${work_dir}/original_section.nc" -Vq
gmt grdcut "${flatten}?Vs" -Ey${section_northing_m} \
	-G"${work_dir}/flatten_section.nc" -Vq
gmt grdcut "${replace_bathy}?Vs" -Ey${section_northing_m} \
	-G"${work_dir}/replace_bathy_section.nc" -Vq
for name in pull extend linear; do
	gmt grdcut "${work_dir}/${name}.nc?Vs" -Ey${section_northing_m} \
		-G"${work_dir}/${name}_section.nc" -Vq
done
gmt grdedit "${work_dir}/original_section.nc" -R250/640/0/5 -Vq
gmt grdedit "${work_dir}/flatten_section.nc" -R250/640/0/2 -Vq
gmt grdedit "${work_dir}/replace_bathy_section.nc" -R250/640/-5/2 -Vq
for name in pull extend linear; do
	gmt grdedit "${work_dir}/${name}_section.nc" -R250/640/-5/2 -Vq
done

# Prepare the inferred and replacement surface profiles and a projected
# coastline for the native-coordinate maps.
awk -v y="${section_northing_m}" 'BEGIN {
	for (x = 250000; x <= 640000; x += 10000) print x, y
}' > "${work_dir}/profile_points.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${old_surface}" | \
	awk '{print 0.001 * $1, $3}' > "${work_dir}/old_surface_profile.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${relief_utm}" | \
	awk '{print 0.001 * $1, -0.001 * $3}' \
	> "${work_dir}/new_surface_profile.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${landmask_utm}" | \
	awk '{print 0.001 * $1, $3}' > "${work_dir}/mask_profile.txt"
paste "${work_dir}/old_surface_profile.txt" \
	"${work_dir}/new_surface_profile.txt" "${work_dir}/mask_profile.txt" | \
	awk '{print $1, ($6 >= 0.5 ? 0 : $4)}' \
	> "${work_dir}/replace_bathy_surface_profile.txt"
paste "${work_dir}/old_surface_profile.txt" \
	"${work_dir}/new_surface_profile.txt" "${work_dir}/mask_profile.txt" | \
	awk '{print $1, ($6 >= 0.5 ? $4 : $2)}' \
	> "${work_dir}/topography_surface_profile.txt"
printf '250 0\n640 0\n' > "${work_dir}/flat_surface_profile.txt"

gmt coast -R-127/-120/43/50 -Dh -A0/0/1 -W -M \
	> "${work_dir}/coast_geo.txt"
gmt mapproject "${work_dir}/coast_geo.txt" -Ju10N/1:1 -C -Fe | \
	awk '/^>/ {print; next} {print 0.001 * $1, 0.001 * $2}' \
	> "${work_dir}/coast_utm_km.txt"

gmt grdmath "${work_dir}/extend_section.nc" \
	"${work_dir}/linear_section.nc" SUB = \
	"${work_dir}/method_difference.nc"
gmt grdinfo "${work_dir}/method_difference.nc" -C | \
	awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'

velocity_cpt="${work_dir}/velocity.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
section_region=250/640/-5/2

# Figure 1: remove and replace the original bathymetry.
flatten_ps="${work_dir}/ex05_cascadia_v16_flattening.ps"
flatten_names=(original flatten replace_bathy)
flatten_titles=("Original" "Bathymetry removed" "Bathymetry replaced")
flatten_letters=(a b c)
for index in 0 1 2; do
	name=${flatten_names[index]}
	title="(${flatten_letters[index]}) ${flatten_titles[index]}"
	y_axis=-Bya100f50
	if ((index == 0)); then
		y_axis=-Bya100f50+l"Northing (km)"
		gmt grdimage "${work_dir}/${name}_map.nc" -P -R${region_km} \
			-JX2i/2.6i -C"${velocity_cpt}" \
			-Bxa100f50+l"Easting (km)" "${y_axis}" \
			"-BWSen+t${title}" -X0.7i -Y3.8i -K > "${flatten_ps}"
	else
		gmt grdimage "${work_dir}/${name}_map.nc" -R -J \
			-C"${velocity_cpt}" -Bxa100f50+l"Easting (km)" \
			"${y_axis}" "-BwSen+t${title}" -X2.25i \
			-O -K >> "${flatten_ps}"
	fi
	gmt psxy "${work_dir}/coast_utm_km.txt" -R -J -W0.7p,black \
		-O -K >> "${flatten_ps}"
	printf '250 %s\n640 %s\n' "${section_northing_km}" \
		"${section_northing_km}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${flatten_ps}"
	plot_depth_label >> "${flatten_ps}"
done

flatten_section_letters=(d e f)
for index in 0 1 2; do
	name=${flatten_names[index]}
	title="(${flatten_section_letters[index]}) ${flatten_titles[index]}"
	y_axis=-Bya1f0.5
	profile="${work_dir}/flat_surface_profile.txt"
	if [[ ${name} == original ]]; then
		profile="${work_dir}/old_surface_profile.txt"
	elif [[ ${name} == replace_bathy ]]; then
		profile="${work_dir}/replace_bathy_surface_profile.txt"
	fi
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Depth (km)"
		gmt grdimage "${work_dir}/${name}_section.nc" \
			-R${section_region} -JX2i/-1.55i -C"${velocity_cpt}" \
			-Bxa100f50+l"Easting (km)" "${y_axis}" \
			"-BWSen+t${title}" -fc -X-4.5i -Y-2.55i \
			-O -K >> "${flatten_ps}"
	else
		gmt grdimage "${work_dir}/${name}_section.nc" -R -J \
			-C"${velocity_cpt}" -Bxa100f50+l"Easting (km)" \
			"${y_axis}" "-BwSen+t${title}" -fc -X2.25i \
			-O -K >> "${flatten_ps}"
	fi
	gmt psxy "${profile}" -R -J -W1.5p,black -fc \
		-O -K >> "${flatten_ps}"
done

gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-4.5i/-0.78i+w6.5i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=10p --FONT_LABEL=10p -O >> "${flatten_ps}"
gmt psconvert "${flatten_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex05_cascadia_v16_flattening"
gmt psconvert "${flatten_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex05_cascadia_v16_flattening"

# Figure 2: add topography while retaining the original bathymetry.
methods_ps="${work_dir}/ex05_cascadia_v16_methods.ps"
method_names=(original pull extend linear)
method_titles=("Original" "Pull-up/push-down" "Constant extension" "Linear extension")
method_letters=(a b c d)
for index in 0 1 2 3; do
	name=${method_names[index]}
	title="(${method_letters[index]}) ${method_titles[index]}"
	y_axis=-Bya100f50
	if ((index == 0)); then
		y_axis=-Bya100f50+l"Northing (km)"
		gmt grdimage "${work_dir}/${name}_map.nc" -P -R${region_km} \
			-JX1.65i/2.12i -C"${velocity_cpt}" \
			-Bxa100f50+l"Easting (km)" "${y_axis}" \
			"-BWSen+t${title}" -X0.7i -Y3.8i -K > "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_map.nc" -R -J \
			-C"${velocity_cpt}" -Bxa100f50+l"Easting (km)" \
			"${y_axis}" "-BwSen+t${title}" -X1.9i \
			-O -K >> "${methods_ps}"
	fi
	gmt psxy "${work_dir}/coast_utm_km.txt" -R -J -W0.7p,black \
		-O -K >> "${methods_ps}"
	printf '250 %s\n640 %s\n' "${section_northing_km}" \
		"${section_northing_km}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${methods_ps}"
	plot_depth_label >> "${methods_ps}"
done

method_section_letters=(e f g h)
for index in 0 1 2 3; do
	name=${method_names[index]}
	title="(${method_section_letters[index]}) ${method_titles[index]}"
	y_axis=-Bya1f0.5
	profile="${work_dir}/topography_surface_profile.txt"
	if [[ ${name} == original ]]; then
		profile="${work_dir}/old_surface_profile.txt"
	fi
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Depth (km)"
		gmt grdimage "${work_dir}/${name}_section.nc" \
			-R${section_region} -JX1.65i/-1.55i -C"${velocity_cpt}" \
			-Bxa100f50+l"Easting (km)" "${y_axis}" \
			"-BWSen+t${title}" -fc -X-5.7i -Y-2.55i \
			-O -K >> "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_section.nc" -R -J \
			-C"${velocity_cpt}" -Bxa100f50+l"Easting (km)" \
			"${y_axis}" "-BwSen+t${title}" -fc -X1.9i \
			-O -K >> "${methods_ps}"
	fi
	gmt psxy "${profile}" -R -J -W1.5p,black -fc \
		-O -K >> "${methods_ps}"
done

gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-5.7i/-0.78i+w7.35i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=10p --FONT_LABEL=10p -O >> "${methods_ps}"
gmt psconvert "${methods_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex05_cascadia_v16_methods"
gmt psconvert "${methods_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex05_cascadia_v16_methods"
