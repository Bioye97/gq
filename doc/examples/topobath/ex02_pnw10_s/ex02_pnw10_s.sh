#!/usr/bin/env bash
#
# Apply three topography construction methods to the flat PNW10-S model.

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
model_file="${data_dir}/PNW10-S_CVM.r0.1.nc"
relief_file="${data_dir}/cascadia_earth_relief_01m_g.nc"

if [[ ! -s "${model_file}" ]]; then
	GMT="${gmt_executable}" "${prepare_script}"
fi
if [[ ! -s "${relief_file}" ]]; then
	gmt grdcut @earth_relief_01m_g -R-130/-116/39/52 \
		-G"${relief_file}"
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-topobath-ex02-pnw10-s.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-124.2/-119/40/49
increment=0.1
section_latitude=47
model="${model_file}?Vs+Zkm"
relief="${relief_file}?z+z-0.001+Zkm"
original="${work_dir}/original.nc"
pull="${work_dir}/pull.nc"
extend="${work_dir}/extend.nc"
linear="${work_dir}/linear.nc"

# Resample the original flat model onto the output lattice, then apply the
# local relief grid with each construction method.
gmt topobath "${model}" -Or -R${region} -I${increment} -T0/2/0.1 \
	-WVs/0+t0.01 -Dh -A0/0/1 -G"${original}"
gmt topobath "${model}" "${relief}" -Oa -Mp -R${region} -I${increment} \
	-T-5/2/0.1 -WVs/0+t0.01 -Dh -A0/0/1 -G"${pull}"
gmt topobath "${model}" "${relief}" -Oa -Me -R${region} -I${increment} \
	-T-5/2/0.1 -WVs/0+t0.01 -Dh -A0/0/1 -G"${extend}"
gmt topobath "${model}" "${relief}" -Oa -Ml -R${region} -I${increment} \
	-T-5/2/0.1 -WVs/0+t0.01 -LVs/0.5 -Dh -A0/0/1 -G"${linear}"

# Extract sea-level maps. The topographic models begin at -5 km, making zero
# depth layer 50 at 0.1 km spacing.
gmt grdconvert "${original}?Vs[0]" "${work_dir}/original_map.nc" -Vq
for name in pull extend linear; do
	gmt grdconvert "${work_dir}/${name}.nc?Vs[50]" \
		"${work_dir}/${name}_map.nc" -Vq
done

# Extract latitude = 47 N sections and pad the flat baseline above zero.
gmt grdcut "${original}?Vs" -Ey${section_latitude} \
	-G"${work_dir}/original_section_native.nc" -Vq
gmt grdcut "${work_dir}/original_section_native.nc" \
	-R-124.2/-119/-5/2 -NNaN -G"${work_dir}/original_section_raw.nc" -Vq
gmt grdmath "${work_dir}/original_section_raw.nc" 0 NAN = \
	"${work_dir}/original_section.nc"
for name in pull extend linear; do
	gmt grdcut "${work_dir}/${name}.nc?Vs" -Ey${section_latitude} \
		-G"${work_dir}/${name}_section.nc" -Vq
done

# Build flat and applied surface profiles in the positive-down convention.
awk -v latitude="${section_latitude}" 'BEGIN {
	for (i = 0; i <= 52; i++) print -124.2 + 0.1 * i, latitude
}' > "${work_dir}/profile_points.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${relief_file}" | \
	awk '{print $1, -0.001 * $3}' > "${work_dir}/new_surface_profile.txt"
printf '%s 0\n%s 0\n' -124.2 -119 > "${work_dir}/flat_surface_profile.txt"

# Confirm that constant and linear extension do not collapse to one result.
gmt grdmath "${work_dir}/extend_section.nc" "${work_dir}/linear_section.nc" \
	SUB = "${work_dir}/method_difference.nc"
gmt grdinfo "${work_dir}/method_difference.nc" -C | \
	awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'

velocity_cpt="${work_dir}/velocity.cpt"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"

map_projection=M1.55i
section_region=-124.2/-119/-5/2
section_projection=X1.55i/-1.45i

figure_ps="${work_dir}/ex02_pnw10_s.ps"
names=(original pull extend linear)
titles=("Original" "Pull/push" "Constant" "Linear")
letters=(a b c d)

for index in 0 1 2 3; do
	name=${names[index]}
	title="(${letters[index]}) ${titles[index]}"
	y_axis=-Bya2f1
	if ((index == 0)); then
		y_axis=-Bya2f1+l"Latitude"
		gmt grdimage "${work_dir}/${name}_map.nc" -P -R${region} \
			-J${map_projection} -C"${velocity_cpt}" \
			-Bxa2f0.2+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
			-X0.4i -Y3.9i -K > "${figure_ps}"
	else
		gmt grdimage "${work_dir}/${name}_map.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -X1.95i \
			-O -K >> "${figure_ps}"
	fi
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 \
		-O -K >> "${figure_ps}"
	printf '%s %s\n%s %s\n' -124.2 "${section_latitude}" -119 \
		"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${figure_ps}"
	plot_depth_label >> "${figure_ps}"
done

section_letters=(e f g h)
for index in 0 1 2 3; do
	name=${names[index]}
	title="(${section_letters[index]}) ${titles[index]}"
	y_axis=-Bya1f0.5
	profile="${work_dir}/new_surface_profile.txt"
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Depth (km)"
		profile="${work_dir}/flat_surface_profile.txt"
		gmt grdimage "${work_dir}/${name}_section.nc" \
			-R${section_region} -J${section_projection} -C"${velocity_cpt}" \
			-Bxa2f0.2+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
			-fc -X-5.85i -Y-2.55i -O -K >> "${figure_ps}"
	else
		gmt grdimage "${work_dir}/${name}_section.nc" -R -J \
			-C"${velocity_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -fc -X1.95i \
			-O -K >> "${figure_ps}"
	fi
	gmt psxy "${profile}" -R -J -W1.5p,black -fc \
		-O -K >> "${figure_ps}"
done

gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-5.85i/-0.78i+w7.4i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=10p --FONT_LABEL=10p -O >> "${figure_ps}"

gmt psconvert "${figure_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex02_pnw10_s"
gmt psconvert "${figure_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex02_pnw10_s"
