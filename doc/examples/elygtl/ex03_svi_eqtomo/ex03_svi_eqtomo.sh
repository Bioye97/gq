#!/usr/bin/env bash
# Apply the USGS Vs30 model to all SVI EQTOMO material properties.

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
model_file="${data_dir}/SVI_EQTOMO_Savard2018.r0.1.nc"
vs30_file="${data_dir}/USGS_global_vs30_cascadia.nc"
[[ -s ${model_file} ]] || GMT="${gmt_executable}" "${data_dir}/prepare_vs_slices.sh"
[[ -s ${vs30_file} ]] || GMT="${gmt_executable}" "${data_dir}/download_usgs_vs30.sh"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-elygtl-ex04-svi.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-126/-121.1/47/50.9
increment=0.1
section_latitude=49
staged_model="${work_dir}/svi_upper.nc"
vs30="${work_dir}/vs30.nc"
output="${work_dir}/elygtl.nc"

# Stage Vp, Vs, and density independently at 50 m, then combine them into one
# multiparameter cube for a single elygtl operation.
for field in Vp Vs Density; do
	layers=()
	for level in 0 1; do
		layer="${work_dir}/${field}_${level}.nc"
		gmt grdsample "${model_file}?${field}[${level}]" \
			-R${region} -I${increment} -rg -nl+c -G"${layer}" -Vq
		layers+=("${layer}")
	done
	gmt grdinterpolate "${layers[@]}" -Z0/3/3 -T0/3/0.05 \
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
gmt elygtl "${staged_model}+z1000+Zm" "${vs30}?vs30" \
	-G"${output}" -Fvp=Vp,vs=Vs,rho=Density -U1000/1000 \
	-Dh -A0/0/1 -Z+z0.001+Zkm

gmt grdsample "${vs30}" -R${region} -I${increment} \
	-G"${work_dir}/vs30_map.nc" -Vq
gmt grdconvert "${staged_model}?Vs[0]" "${work_dir}/original_map.nc" -Vq
gmt grdconvert "${output}?Vs[0]" "${work_dir}/ely_map.nc" -Vq

for field in Vp Vs Density; do
	key=$(printf '%s' "${field}" | tr '[:upper:]' '[:lower:]')
	gmt grdcut "${staged_model}?${field}" -Ey${section_latitude} \
		-G"${work_dir}/original_${key}_depth_section.nc" -Vq
	gmt grdcut "${output}?${field}" -Ey${section_latitude} \
		-G"${work_dir}/ely_${key}_depth_section.nc" -Vq
	gmt grdedit "${work_dir}/original_${key}_depth_section.nc" -Ev \
		-G"${work_dir}/original_${key}_section.nc" -Vq
	gmt grdedit "${work_dir}/ely_${key}_depth_section.nc" -Ev \
		-G"${work_dir}/ely_${key}_section.nc" -Vq
	gmt grdedit "${work_dir}/original_${key}_section.nc" \
		-R-126/-121.1/-3/0 -Vq
	gmt grdedit "${work_dir}/ely_${key}_section.nc" \
		-R-126/-121.1/-3/0 -Vq
	gmt grdmath "${work_dir}/ely_${key}_section.nc" \
		"${work_dir}/original_${key}_section.nc" SUB = \
		"${work_dir}/difference_${key}_section.nc"
done
cp "${work_dir}/original_vs_section.nc" "${work_dir}/original_section.nc"
cp "${work_dir}/ely_vs_section.nc" "${work_dir}/ely_section.nc"
cp "${work_dir}/difference_vs_section.nc" "${work_dir}/difference_section.nc"
printf '%s %s\n%s %s\n' -126 "${section_latitude}" -121.1 \
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

elygtl_plot_vs "${script_dir}/ex03_svi_eqtomo" "${region}" \
	-126/-121.1/-3/0 X2.3i/2.3i X2.3i/1.6i \
	-Bxa1f0.2+l"Longitude" -Bya1f0.5+l"Latitude" \
	-Bxa1f0.2+l"Longitude" -Bya0.5f0.25+l"Elevation (km)" geographic

elygtl_plot_parameters "${script_dir}/ex03_svi_eqtomo_parameters" \
	-126/-121.1/-3/0 X2.3i/1.55i \
	-Bxa1f0.2+l"Longitude" -Bya0.5f0.25+l"Elevation (km)" \
	"vp:Vp:${vp_cpt}:-Bxa2f1+lVp (km/s)" \
	"vs:Vs:${velocity_cpt}:-Bxa1f0.5+lVs (km/s)" \
	"density:Density:${density_cpt}:-Bxa0.5f0.25+lDensity (g/cm@+3@+)"
