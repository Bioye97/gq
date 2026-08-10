#!/usr/bin/env bash
# Apply the USGS Vs30 model to the flat-surface PNW10-S model.

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
model_file="${data_dir}/PNW10-S_CVM.r0.1.nc"
vs30_file="${data_dir}/USGS_global_vs30_cascadia.nc"
[[ -s ${model_file} ]] || GMT="${gmt_executable}" "${data_dir}/prepare_vs_slices.sh"
[[ -s ${vs30_file} ]] || GMT="${gmt_executable}" "${data_dir}/download_usgs_vs30.sh"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-elygtl-ex03-pnw10.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-124.2/-119/39/49
increment=0.2
section_latitude=47
staged_model="${work_dir}/pnw10_upper.nc"
vs30="${work_dir}/vs30.nc"
output="${work_dir}/elygtl.nc"

layers=()
for level in 0 1; do
	layer="${work_dir}/vs_${level}.nc"
	gmt grdsample "${model_file}?Vs[${level}]" -R${region} -I${increment} \
		-rg -nl+c -G"${layer}" -Vq
	layers+=("${layer}")
done
gmt grdinterpolate "${layers[@]}" -Z0/2.5/2.5 -T0/2.5/0.05 \
	-G"${staged_model}" \
	-D+xdegrees_east+ydegrees_north+zkm+d"km/s"+vVs -Vq
gmt grdmath "${vs30_file}?vs30" 98 LT NaN "${vs30_file}?vs30" \
	IFELSE = "${vs30}"

gmt elygtl "${staged_model}+z1000+Zm" "${vs30}?vs30" \
	-G"${output}" -Fvs=Vs -U1000 -Dh -A0/0/1 -Z+z0.001+Zkm

gmt grdsample "${vs30}" -R${region} -I${increment} \
	-G"${work_dir}/vs30_map.nc" -Vq
gmt grdconvert "${staged_model}?Vs[0]" "${work_dir}/original_map.nc" -Vq
gmt grdconvert "${output}?Vs[0]" "${work_dir}/ely_map.nc" -Vq
gmt grdcut "${staged_model}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/original_depth_section.nc" -Vq
gmt grdcut "${output}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/ely_depth_section.nc" -Vq
gmt grdedit "${work_dir}/original_depth_section.nc" -Ev \
	-G"${work_dir}/original_section.nc" -Vq
gmt grdedit "${work_dir}/ely_depth_section.nc" -Ev \
	-G"${work_dir}/ely_section.nc" -Vq
gmt grdedit "${work_dir}/original_section.nc" -R-124.2/-119/-2.5/0 -Vq
gmt grdedit "${work_dir}/ely_section.nc" -R-124.2/-119/-2.5/0 -Vq
gmt grdmath "${work_dir}/ely_section.nc" \
	"${work_dir}/original_section.nc" SUB = \
	"${work_dir}/difference_section.nc"
printf '%s %s\n%s %s\n' -124.2 "${section_latitude}" -119 \
	"${section_latitude}" > "${work_dir}/profile_map.txt"

velocity_cpt="${work_dir}/velocity.cpt"
vs30_cpt="${work_dir}/vs30.cpt"
difference_cpt="${work_dir}/difference.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
gmt makecpt -Cturbo -T100/900/20 -Z > "${vs30_cpt}"
gmt makecpt -Cvik -T-2/2/0.05 -Z > "${difference_cpt}"

elygtl_plot_vs "${script_dir}/ex02_pnw10_s" "${region}" \
	-124.2/-119/-2.5/0 X2.15i/2.3i X2.15i/1.6i \
	-Bxa1f0.2+l"Longitude" -Bya2f1+l"Latitude" \
	-Bxa1f0.2+l"Longitude" -Bya0.5f0.25+l"Elevation (km)" geographic
