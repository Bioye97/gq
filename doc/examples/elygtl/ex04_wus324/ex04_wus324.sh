#!/usr/bin/env bash
# Apply the USGS Vs30 model to the topographic WUS324 Cascadia model.

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
model_file="${data_dir}/WUS324-Casc-CVM.r0.0-n4.nc"
vs30_file="${data_dir}/USGS_global_vs30_cascadia.nc"
[[ -s ${model_file} ]] || GMT="${gmt_executable}" "${data_dir}/prepare_vs_slices.sh"
[[ -s ${vs30_file} ]] || GMT="${gmt_executable}" "${data_dir}/download_usgs_vs30.sh"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-elygtl-ex05-wus324.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-128/-118/40/51
increment=0.25
section_latitude=47
staged_model="${work_dir}/wus324_upper.nc"
vs30="${work_dir}/vs30.nc"
output="${work_dir}/elygtl.nc"

for field in Vp Vs Density; do
	layers=()
	for level in 0 1 2 3 4 5; do
		layer="${work_dir}/${field}_${level}.nc"
		gmt grdsample "${model_file}?${field}[${level}]" \
			-R${region} -I${increment} -rg -nl+c -G"${layer}" -Vq
		layers+=("${layer}")
	done
	gmt grdinterpolate "${layers[@]}" -Z-4/1/1 -T-4/1/0.05 \
		-G"${work_dir}/${field}_cube.nc" \
		-D+xdegrees_east+ydegrees_north+zkm+v${field} -Vq
done
"${CC:-cc}" -O2 -I/usr/local/include \
	"${script_dir}/../combine_cubes.c" -L/usr/local/lib -lnetcdf \
	-o "${work_dir}/combine_cubes"
"${work_dir}/combine_cubes" "${staged_model}" \
	Vp="${work_dir}/Vp_cube.nc" Vs="${work_dir}/Vs_cube.nc" \
	Density="${work_dir}/Density_cube.nc"

gmt grdmath "${vs30_file}?vs30" 98 LT NaN "${vs30_file}?vs30" \
	IFELSE = "${vs30}"

# WUS324 stores density in kg/m^3 while velocity is in km/s. Convert density
# to g/cm^3 before the SI conversion so all output fields use plotting units.
gmt elygtl "${staged_model}+z1000+Zm+v1,1,0.001" "${vs30}?vs30" \
	-G"${output}" -Fvp=Vp,vs=Vs,rho=Density -U1000/1000 \
	-Dh -A0/0/1 -Z+z0.001+Zkm

gmt grdsample "${vs30}" -R${region} -I${increment} \
	-G"${work_dir}/vs30_map.nc" -Vq
elygtl_surface_map "${staged_model}" Vs 100 "${work_dir}/original_map.nc" 20
elygtl_surface_map "${output}" Vs 100 "${work_dir}/ely_map.nc" 20

for field in Vp Vs Density; do
	key=$(printf '%s' "${field}" | tr '[:upper:]' '[:lower:]')
	gmt grdcut "${staged_model}?${field}" -Ey${section_latitude} \
		-G"${work_dir}/original_${key}_depth_section.nc" -Vq
	if [[ ${field} == Density ]]; then
		gmt grdmath "${work_dir}/original_${key}_depth_section.nc" 0.001 MUL = \
			"${work_dir}/original_${key}_scaled.nc"
		mv "${work_dir}/original_${key}_scaled.nc" \
			"${work_dir}/original_${key}_depth_section.nc"
	fi
	gmt grdcut "${output}?${field}" -Ey${section_latitude} \
		-G"${work_dir}/ely_${key}_depth_section.nc" -Vq
	gmt grdedit "${work_dir}/original_${key}_depth_section.nc" -Ev \
		-G"${work_dir}/original_${key}_section.nc" -Vq
	gmt grdedit "${work_dir}/ely_${key}_depth_section.nc" -Ev \
		-G"${work_dir}/ely_${key}_section.nc" -Vq
	gmt grdedit "${work_dir}/original_${key}_section.nc" \
		-R-128/-118/-1/4 -Vq
	gmt grdedit "${work_dir}/ely_${key}_section.nc" \
		-R-128/-118/-1/4 -Vq
	gmt grdmath "${work_dir}/ely_${key}_section.nc" \
		"${work_dir}/original_${key}_section.nc" SUB = \
		"${work_dir}/difference_${key}_section.nc"
done
cp "${work_dir}/original_vs_section.nc" "${work_dir}/original_section.nc"
cp "${work_dir}/ely_vs_section.nc" "${work_dir}/ely_section.nc"
cp "${work_dir}/difference_vs_section.nc" "${work_dir}/difference_section.nc"
printf '%s %s\n%s %s\n' -128 "${section_latitude}" -118 \
	"${section_latitude}" > "${work_dir}/profile_map.txt"

velocity_cpt="${work_dir}/vs.cpt"
vs30_cpt="${work_dir}/vs30.cpt"
difference_cpt="${work_dir}/difference.cpt"
vp_cpt="${work_dir}/vp.cpt"
density_cpt="${work_dir}/density.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
gmt makecpt -Cturbo -T100/900/20 -Z > "${vs30_cpt}"
gmt makecpt -Cvik -T-2/2/0.05 -Z > "${difference_cpt}"
gmt makecpt -Cturbo -T1.5/8/0.1 -Z > "${vp_cpt}"
gmt makecpt -Cturbo -T1/3.5/0.05 -Z > "${density_cpt}"

elygtl_plot_vs "${script_dir}/ex04_wus324" "${region}" \
	-128/-118/-1/4 X2.15i/2.3i X2.15i/1.6i \
	-Bxa2f1+l"Longitude" -Bya2f1+l"Latitude" \
	-Bxa2f1+l"Longitude" -Bya1f0.5+l"Elevation (km)" geographic

elygtl_plot_parameters "${script_dir}/ex04_wus324_parameters" \
	-128/-118/-1/4 X2.15i/1.55i \
	-Bxa2f1+l"Longitude" -Bya1f0.5+l"Elevation (km)" \
	"vp:Vp:${vp_cpt}:-Bxa2f1+lVp (km/s)" \
	"vs:Vs:${velocity_cpt}:-Bxa1f0.5+lVs (km/s)" \
	"density:Density:${density_cpt}:-Bxa0.5f0.25+lDensity (g/cm@+3@+)"
