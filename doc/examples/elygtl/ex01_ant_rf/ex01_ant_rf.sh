#!/usr/bin/env bash
# Apply the USGS Vs30 model to the topographic Cascadia ANT+RF model.

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
model_file="${data_dir}/Cascadia-ANT+RF-Delph2018.r0.1.nc"
vs30_file="${data_dir}/USGS_global_vs30_cascadia.nc"
[[ -s ${model_file} ]] || GMT="${gmt_executable}" "${data_dir}/prepare_vs_slices.sh"
[[ -s ${vs30_file} ]] || GMT="${gmt_executable}" "${data_dir}/download_usgs_vs30.sh"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-elygtl-ex02-ant-rf.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-124.8/-120/40/49
increment=0.2
section_latitude=47
staged_model="${work_dir}/ant_rf_upper.nc"
vs30="${work_dir}/vs30.nc"
output="${work_dir}/elygtl.nc"

# Retain the five shallow native layers on their increasing positive-down depth
# axis, then interpolate them to 50 m spacing for the 350 m transition.
layers=()
for level in 0 1 2 3 4; do
	layer="${work_dir}/vs_${level}.nc"
	gmt grdsample "${model_file}?Vs[${level}]" -R${region} -I${increment} \
		-rg -nl+c -G"${layer}" -Vq
	layers+=("${layer}")
done
gmt grdinterpolate "${layers[@]}" -Z-3/1/1 -T-3/1/0.05 \
	-G"${staged_model}" \
	-D+xdegrees_east+ydegrees_north+zkm+d"km/s"+vVs -Vq

# The official mosaic range begins at 98 m/s. Mask lower extraction artifacts
# before sampling Vs30 at the model nodes.
gmt grdmath "${vs30_file}?vs30" 98 LT NaN "${vs30_file}?vs30" \
	IFELSE = "${vs30}"

gmt elygtl "${staged_model}+z1000+Zm" "${vs30}?vs30" \
	-G"${output}" -Fvs=Vs -U1000 -Dh -A0/0/1 -Z+z0.001+Zkm

gmt grdsample "${vs30}" -R${region} -I${increment} \
	-G"${work_dir}/vs30_map.nc" -Vq
elygtl_surface_map "${staged_model}" Vs 80 "${work_dir}/original_map.nc" 20
elygtl_surface_map "${output}" Vs 80 "${work_dir}/ely_map.nc" 20

# Flip plot-only copies from increasing depth to increasing elevation. The model
# cubes themselves remain in the positive-down convention required by elygtl.
gmt grdcut "${staged_model}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/original_depth_section.nc" -Vq
gmt grdcut "${output}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/ely_depth_section.nc" -Vq
gmt grdedit "${work_dir}/original_depth_section.nc" -Ev \
	-G"${work_dir}/original_section.nc" -Vq
gmt grdedit "${work_dir}/ely_depth_section.nc" -Ev \
	-G"${work_dir}/ely_section.nc" -Vq
gmt grdedit "${work_dir}/original_section.nc" -R-124.8/-120/-1/3 -Vq
gmt grdedit "${work_dir}/ely_section.nc" -R-124.8/-120/-1/3 -Vq
gmt grdmath "${work_dir}/ely_section.nc" \
	"${work_dir}/original_section.nc" SUB = \
	"${work_dir}/difference_section.nc"
printf '%s %s\n%s %s\n' -124.8 "${section_latitude}" -120 \
	"${section_latitude}" > "${work_dir}/profile_map.txt"

velocity_cpt="${work_dir}/velocity.cpt"
vs30_cpt="${work_dir}/vs30.cpt"
difference_cpt="${work_dir}/difference.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
gmt makecpt -Cturbo -T100/900/20 -Z > "${vs30_cpt}"
gmt makecpt -Cvik -T-2/2/0.05 -Z > "${difference_cpt}"

elygtl_plot_vs "${script_dir}/ex01_ant_rf" "${region}" \
	-124.8/-120/-1/3 X2.3i/2.3i X2.3i/1.6i \
	-Bxa1f0.2+l"Longitude" -Bya2f1+l"Latitude" \
	-Bxa1f0.2+l"Longitude" -Bya1f0.5+l"Elevation (km)" geographic
