#!/usr/bin/env bash
# Fill ANT+RF gaps and apply Ely GTL with variable transition thickness.

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

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-elygtl-ex06-ant-rf.XXXXXX")
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
transition="${work_dir}/transition_thickness.nc"
output="${work_dir}/elygtl.nc"

# Stage seven native layers through 3 km depth. The extra depth provides an
# anchor below the largest 1000 m transition, including low-elevation columns.
layers=()
for level in 0 1 2 3 4 5 6; do
	layer="${work_dir}/vs_${level}.nc"
	gmt grdsample "${model_file}?Vs[${level}]" -R${region} -I${increment} \
		-rg -nl+c -G"${layer}" -Vq
	layers+=("${layer}")
done
gmt grdinterpolate "${layers[@]}" -Z-3/3/1 -T-3/3/0.05 \
	-G"${staged_model}" \
	-D+xdegrees_east+ydegrees_north+zkm+d"km/s"+vVs -Vq

# Increase transition thickness linearly from 100 m in the southwest to
# 1000 m in the northeast. The grid is already expressed in metres.
gmt grdmath -R${region} -I${increment} -rg \
	X -124.8 SUB 4.8 DIV Y 40 SUB 9 DIV ADD 0.5 MUL \
	900 MUL 100 ADD = "${transition}"

# The official mosaic range begins at 98 m/s. Mask lower extraction artifacts
# before sampling Vs30 at the model nodes.
gmt grdmath "${vs30_file}?vs30" 98 LT NaN "${vs30_file}?vs30" \
	IFELSE = "${vs30}"

# -Hl fills enclosed horizontal holes with linear Delaunay interpolation.
# -Sl+g uses linear vertical interpolation and bridges internal z gaps.
gmt elygtl "${staged_model}+z1000+Zm" "${vs30}?vs30" \
	-G"${output}" -Fvs=Vs -U1000 -E"${transition}" -Hl -Sl+g \
	-Dh -A0/0/1 -Z+z0.001+Zkm

gmt grdsample "${vs30}" -R${region} -I${increment} \
	-G"${work_dir}/vs30_map.nc" -Vq
elygtl_surface_map "${staged_model}" Vs 120 "${work_dir}/original_map.nc" 20
elygtl_surface_map "${output}" Vs 120 "${work_dir}/ely_map.nc" 20

# Flip plot-only copies from increasing depth to increasing elevation. The
# model cubes remain in the positive-down convention required by elygtl.
gmt grdcut "${staged_model}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/original_depth_section.nc" -Vq
gmt grdcut "${output}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/ely_depth_section.nc" -Vq
gmt grdedit "${work_dir}/original_depth_section.nc" -Ev \
	-G"${work_dir}/original_section.nc" -Vq
gmt grdedit "${work_dir}/ely_depth_section.nc" -Ev \
	-G"${work_dir}/ely_section.nc" -Vq
gmt grdedit "${work_dir}/original_section.nc" -R-124.8/-120/-3/3 -Vq
gmt grdedit "${work_dir}/ely_section.nc" -R-124.8/-120/-3/3 -Vq
gmt grdmath "${work_dir}/ely_section.nc" \
	"${work_dir}/original_section.nc" SUB = \
	"${work_dir}/difference_section.nc"
printf '%s %s\n%s %s\n' -124.8 "${section_latitude}" -120 \
	"${section_latitude}" > "${work_dir}/profile_map.txt"

velocity_cpt="${work_dir}/velocity.cpt"
vs30_cpt="${work_dir}/vs30.cpt"
difference_cpt="${work_dir}/difference.cpt"
transition_cpt="${work_dir}/transition.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"
gmt makecpt -Cturbo -T100/900/20 -Z > "${vs30_cpt}"
gmt makecpt -Cvik -T-2/2/0.05 -Z > "${difference_cpt}"
gmt makecpt -Cbatlow -T100/1000/25 -Z > "${transition_cpt}"

gmt grdconvert "${transition}" "${work_dir}/transition_map.nc" -Vq

ps="${work_dir}/ex06_ant_rf_gaps.ps"
maps=(vs30 transition original ely)
map_titles=("USGS Vs30" "Transition thickness" "Original surface" \
	"Ely GTL surface")
map_cpts=("${vs30_cpt}" "${transition_cpt}" "${velocity_cpt}" \
	"${velocity_cpt}")
map_letters=(a b c d)

for index in 0 1 2 3; do
	if ((index == 0)); then
		gmt grdimage "${work_dir}/${maps[index]}_map.nc" -R${region} \
			-JX2.1i/2.3i -C"${map_cpts[index]}" \
			-Bxa1f0.2+l"Longitude" -Bya2f1+l"Latitude" \
			-BWSen \
			-X0.55i -Y4.5i -K > "${ps}"
	else
		gmt grdimage "${work_dir}/${maps[index]}_map.nc" -R -J \
			-C"${map_cpts[index]}" -Bxa1f0.2+l"Longitude" \
			-BwSen \
			-X2.35i -O -K >> "${ps}"
	fi
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps}"
	gmt psxy "${work_dir}/profile_map.txt" -R -J -W1.5p,black,-- \
		-O -K >> "${ps}"
	printf '%s %s %s\n' -122.4 49 \
		"(${map_letters[index]}) ${map_titles[index]}" | \
		gmt pstext -R -J -F+f11p+jBC -D0/0.24i -N -O -K >> "${ps}"
done

sections=(original ely difference)
section_titles=("Original" "Ely GTL" "Difference")
section_letters=(e f g)
section_cpts=("${velocity_cpt}" "${velocity_cpt}" "${difference_cpt}")

for index in 0 1 2; do
	if ((index == 0)); then
		gmt grdimage "${work_dir}/${sections[index]}_section.nc" \
			-R-124.8/-120/-1/3 -JX2.45i/1.6i \
			-C"${section_cpts[index]}" -Bxa1f0.2+l"Longitude" \
			-Bya1f0.5+l"Elevation (km)" \
			"-BWSen+t(${section_letters[index]}) ${section_titles[index]}" \
			-fc -X-6.375i -Y-3.5i -O -K >> "${ps}"
	else
		gmt grdimage "${work_dir}/${sections[index]}_section.nc" -R -J \
			-C"${section_cpts[index]}" -Bxa1f0.2+l"Longitude" \
			"-BwSen+t(${section_letters[index]}) ${section_titles[index]}" \
			-fc -X2.7i -O -K >> "${ps}"
	fi
done

# Place map-specific scales between the rows and section scales below.
gmt psscale -R -J -C"${vs30_cpt}" \
	-Dx-6.075i/2.65i+w2.1i/0.11i+h -Bxa200f100+l"Vs30 (m/s)" \
	--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
	--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
gmt psscale -R -J -C"${transition_cpt}" \
	-Dx-3.725i/2.65i+w2.1i/0.11i+h -Bxa200f100+l"Thickness (m)" \
	--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
	--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-1.375i/2.65i+w2.1i/0.11i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
	--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx0.975i/2.65i+w2.1i/0.11i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
	--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-5.4i/-0.65i+w2.45i/0.11i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
	--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-2.7i/-0.65i+w2.45i/0.11i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
	--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
gmt psscale -R -J -C"${difference_cpt}" \
	-Dx0i/-0.65i+w2.45i/0.11i+h -Bxa1f0.5+l"Difference (km/s)" \
	--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
	--FONT_LABEL=${elygtl_colorbar_font} -O >> "${ps}"

gmt psconvert "${ps}" -A+m0.12i -Tf -F"${script_dir}/ex06_ant_rf_gaps"
gmt psconvert "${ps}" -A+m0.12i -Tg -E300 \
	-F"${script_dir}/ex06_ant_rf_gaps"
