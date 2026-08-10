#!/usr/bin/env bash
# Apply projected USGS Vs30 to the UTM Cascadia v1.6 model.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z ${gmt_executable} ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() {
	if [[ $1 == elygtl && -n ${GQ_ELYGTL_RUNNER:-} ]]; then
		shift
		GQ_PLUGIN="${GQ_PLUGIN:?GQ_PLUGIN is required}" \
			command "${GQ_ELYGTL_RUNNER}" "$@"
	else
		command "${gmt_executable}" "$@"
	fi
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
data_dir="${script_dir}/../../data/cascadia"
source "${script_dir}/../cascadia_common.sh"
model_file="${data_dir}/casc1.6-velmdl.r1.0-n4.nc"
vs30_file="${data_dir}/USGS_global_vs30_cascadia.nc"
[[ -s ${model_file} ]] || GMT="${gmt_executable}" "${data_dir}/prepare_vs_slices.sh"
[[ -s ${vs30_file} ]] || GMT="${gmt_executable}" "${data_dir}/download_usgs_vs30.sh"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-elygtl-ex06-casc16.XXXXXX")
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
staged_model="${work_dir}/cascadia_v16_upper.nc"
vs30_geo="${work_dir}/vs30_geo.nc"
vs30_utm="${work_dir}/vs30_utm.nc"
landmask_geo="${work_dir}/landmask_geo.nc"
landmask_utm="${work_dir}/landmask_utm.nc"
output="${work_dir}/elygtl.nc"

# Read only two native layers, crop them immediately, and refine the upper
# 500 m to 50 m spacing. This avoids loading the full dense 3-D model.
for field in Vp Vs; do
	layers=()
	for level in 0 1; do
		layer="${work_dir}/${field}_${level}.nc"
		gmt grdsample "${model_file}?${field}[${level}]" \
			-R${region_m} -I${increment_m} -rg -nl+c -G"${layer}" -Vq
		layers+=("${layer}")
	done
	gmt grdinterpolate "${layers[@]}" -Z0/500/500 -T0/500/50 \
		-G"${work_dir}/${field}_cube.nc" -D+xm+ym+zm+v${field} -Vq
done
"${CC:-cc}" -O2 -I/usr/local/include \
	"${script_dir}/../combine_cubes.c" -L/usr/local/lib -lnetcdf \
	-o "${work_dir}/combine_cubes"
"${work_dir}/combine_cubes" "${staged_model}" \
	Vp="${work_dir}/Vp_cube.nc" Vs="${work_dir}/Vs_cube.nc"

# Vs30 and the shoreline classification must be reprojected, not merely
# rescaled, because this model uses UTM Zone 10 coordinates.
gmt grdmath "${vs30_file}?vs30" 98 LT NaN "${vs30_file}?vs30" \
	IFELSE = "${vs30_geo}"
gmt grdproject "${vs30_geo}" -Ju10N/1:1 -C -Fe \
	-R${ancillary_region_m}+ue -D${increment_m} -nl+c -G"${vs30_utm}"
gmt grdlandmask -R-130/-116/39/52 -I1m -Dh -A0/0/1 \
	-N0/1/1/1/1 -G"${landmask_geo}"
gmt grdproject "${landmask_geo}" -Ju10N/1:1 -C -Fe \
	-R${ancillary_region_m}+ue -D${increment_m} -nn -G"${landmask_utm}"

# Convert native m/s values to km/s before -U restores SI units internally.
gmt elygtl "${staged_model}+z1+Zm+v0.001,0.001" "${vs30_utm}" \
	-G"${output}" -Fvp=Vp,vs=Vs -U1000 -K"${landmask_utm}" \
	-Z+z1+Zm

gmt grdsample "${vs30_utm}" -R${region_m} -I${increment_m} \
	-G"${work_dir}/vs30_map.nc" -Vq
gmt grdconvert "${staged_model}?Vs[0]" "${work_dir}/original_map.nc" -Vq
gmt grdmath "${work_dir}/original_map.nc" 0.001 MUL = \
	"${work_dir}/original_map_scaled.nc"
mv "${work_dir}/original_map_scaled.nc" "${work_dir}/original_map.nc"
gmt grdconvert "${output}?Vs[0]" "${work_dir}/ely_map.nc" -Vq
for name in vs30 original ely; do
	gmt grdedit "${work_dir}/${name}_map.nc" -R${region_km} -Vq
done

for field in Vp Vs; do
	key=$(printf '%s' "${field}" | tr '[:upper:]' '[:lower:]')
	gmt grdcut "${staged_model}?${field}" -Ey${section_northing_m} \
		-G"${work_dir}/original_${key}_depth_section.nc" -Vq
	gmt grdmath "${work_dir}/original_${key}_depth_section.nc" 0.001 MUL = \
		"${work_dir}/original_${key}_scaled.nc"
	mv "${work_dir}/original_${key}_scaled.nc" \
		"${work_dir}/original_${key}_depth_section.nc"
	gmt grdcut "${output}?${field}" -Ey${section_northing_m} \
		-G"${work_dir}/ely_${key}_depth_section.nc" -Vq
	gmt grdedit "${work_dir}/original_${key}_depth_section.nc" -Ev \
		-G"${work_dir}/original_${key}_section.nc" -Vq
	gmt grdedit "${work_dir}/ely_${key}_depth_section.nc" -Ev \
		-G"${work_dir}/ely_${key}_section.nc" -Vq
	gmt grdedit "${work_dir}/original_${key}_section.nc" \
		-R250/640/-0.5/0 -Vq
	gmt grdedit "${work_dir}/ely_${key}_section.nc" \
		-R250/640/-0.5/0 -Vq
	gmt grdmath "${work_dir}/ely_${key}_section.nc" \
		"${work_dir}/original_${key}_section.nc" SUB = \
		"${work_dir}/difference_${key}_section.nc"
done
cp "${work_dir}/original_vs_section.nc" "${work_dir}/original_section.nc"
cp "${work_dir}/ely_vs_section.nc" "${work_dir}/ely_section.nc"
cp "${work_dir}/difference_vs_section.nc" "${work_dir}/difference_section.nc"

printf '250 %s\n640 %s\n' "${section_northing_km}" \
	"${section_northing_km}" > "${work_dir}/profile_map.txt"
gmt coast -R-127/-120/43/50 -Dh -A0/0/1 -W -M \
	> "${work_dir}/coast_geo.txt"
gmt mapproject "${work_dir}/coast_geo.txt" -Ju10N/1:1 -C -Fe | \
	awk '/^>/ {print; next} {print 0.001 * $1, 0.001 * $2}' \
	> "${work_dir}/coast_utm_km.txt"

velocity_cpt="${work_dir}/vs.cpt"
vs30_cpt="${work_dir}/vs30.cpt"
difference_cpt="${work_dir}/difference.cpt"
vp_cpt="${work_dir}/vp.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
gmt makecpt -Cturbo -T100/900/20 -Z > "${vs30_cpt}"
gmt makecpt -Cvik -T-2/2/0.05 -Z > "${difference_cpt}"
gmt makecpt -Cturbo -T1.5/8/0.1 -Z > "${vp_cpt}"

elygtl_plot_vs "${script_dir}/ex05_cascadia_v16" "${region_km}" \
	250/640/-0.5/0 X2.15i/2.3i X2.15i/1.6i \
	-Bxa100f50+l"Easting (km)" -Bya100f50+l"Northing (km)" \
	-Bxa100f50+l"Easting (km)" -Bya0.1f0.05+l"Elevation (km)" \
	"${work_dir}/coast_utm_km.txt"

elygtl_plot_parameters "${script_dir}/ex05_cascadia_v16_parameters" \
	250/640/-0.5/0 X2.15i/1.55i \
	-Bxa100f50+l"Easting (km)" -Bya0.1f0.05+l"Elevation (km)" \
	"vp:Vp:${vp_cpt}:-Bxa2f1+lVp (km/s)" \
	"vs:Vs:${velocity_cpt}:-Bxa1f0.5+lVs (km/s)"
