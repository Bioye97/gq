#!/usr/bin/env bash
#
# Fill internal x-y and z gaps before tiling and merging Cascadia Vs models.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prepare_script="${script_dir}/../../data/cascadia/prepare_vs_slices.sh"
if [[ -n "${GQ_EXAMPLE_DATA:-}" ]]; then
	data_dir="${GQ_EXAMPLE_DATA}/cascadia"
else
	data_dir="${script_dir}/../../data/cascadia"
fi
GMT="${gmt_executable}" "${prepare_script}"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex17-cascadia.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

svi="${data_dir}/SVI_EQTOMO_Savard2018.r0.1.nc?Vs+Vkm/s"
ant_rf="${data_dir}/Cascadia-ANT+RF-Delph2018.r0.1.nc?Vs+Vkm/s"
wus324="${data_dir}/WUS324-Casc-CVM.r0.0-n4.nc?Vs+Vkm/s"
svi_slice="${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
ant_rf_slice="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
region=-130/-116/39/52
increment=0.05
zrange=0/60/1
map_projection=M2.2i
section_region=-130/-116/0/60
section_projection=X2.2i/-1.7i
section_latitude=47
section_depth=2
taper_ratios=0.49/0.49/0.49/0.49/0/0.49
mergefile="${work_dir}/cascadia_interpolation.merge3d"
velocity_cpt="${work_dir}/velocity.cpt"
colorbar_font=9.8p

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

cat > "${mergefile}" <<- EOF
	${svi} ${wus324} - - cosine/cosine/cosine ${taper_ratios}
	${ant_rf} ${wus324} - - cosine/cosine/cosine ${taper_ratios}
	${wus324} - - - - -
	EOF

# Fill internal x-y holes, then bridge internal z gaps before merging.
gmt merge3d "${svi}" "${ant_rf}" "${wus324}" -R${region} \
	-I${increment} -T${zrange} -Cf -Fvs -Hl -Sl+g \
	-G"${work_dir}/tiled.nc"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvs -Hl -Sl+g -P -G"${work_dir}/merged.nc"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvs -Hl -Sl+g -A -P -G"${work_dir}/aggregate.nc"

for name in tiled merged aggregate; do
	gmt grdconvert "${work_dir}/${name}.nc?vs[${section_depth}]" \
		"${work_dir}/${name}_horizontal.nc"
	gmt grdcut "${work_dir}/${name}.nc?vs" -Ey${section_latitude} \
		-G"${work_dir}/${name}_vertical.nc"
done

for view in horizontal vertical; do
	gmt grdmath "${work_dir}/merged_${view}.nc" \
		"${work_dir}/tiled_${view}.nc" SUB = \
		"${work_dir}/merged_difference_${view}.nc"
	gmt grdinfo "${work_dir}/merged_difference_${view}.nc" -C | \
		awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
	gmt grdmath "${work_dir}/aggregate_${view}.nc" \
		"${work_dir}/merged_${view}.nc" SUB = \
		"${work_dir}/aggregate_difference_${view}.nc"
	gmt grdinfo "${work_dir}/aggregate_difference_${view}.nc" -C | \
		awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
done

gmt grdinfo "${svi_slice}" -C | awk '{
	print $2, $4; print $3, $4; print $3, $5; print $2, $5; print $2, $4
}' > "${work_dir}/svi_horizontal_outline.txt"
gmt grdinfo "${ant_rf_slice}" -C | awk '{
	print $2, $4; print $3, $4; print $3, $5; print $2, $5; print $2, $4
}' > "${work_dir}/ant_horizontal_outline.txt"
gmt grdinfo "${svi_slice}" -C | awk '{
	print $2, 0; print $3, 0; print $3, 60; print $2, 60; print $2, 0
}' > "${work_dir}/svi_vertical_outline.txt"
gmt grdinfo "${ant_rf_slice}" -C | awk '{
	print $2, 0; print $3, 0; print $3, 60; print $2, 60; print $2, 0
}' > "${work_dir}/ant_vertical_outline.txt"

gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"

plot_horizontal() {
	local ps_file="${work_dir}/ex17_horizontal.ps"
	local names=(tiled merged aggregate)
	local titles=("Tiling" "Merging" "Aggregate")
	local letters=(a b c)
	for index in 0 1 2; do
		name=${names[index]}
		title="(${letters[index]}) ${titles[index]}: z = ${section_depth} km"
		y_axis=-Bya5f1
		if ((index == 0)); then
			y_axis=-Bya5f1+l"Latitude"
			gmt grdimage "${work_dir}/${name}_horizontal.nc" -P \
				-R${region} -J${map_projection} -C"${velocity_cpt}" \
				-Bxa5f1+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
				-X0.45i -Y2.15i -K > "${ps_file}"
		else
			gmt grdimage "${work_dir}/${name}_horizontal.nc" -R -J \
				-C"${velocity_cpt}" -Bxa5f1+l"Longitude" "${y_axis}" \
				"-BWSen+t${title}" -X2.75i -O -K >> "${ps_file}"
		fi
		gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
		printf "%s %s\n%s %s\n" -130 "${section_latitude}" -116 "${section_latitude}" | \
			gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
		if ((index == 0)); then
			gmt psxy "${work_dir}/svi_horizontal_outline.txt" -R -J \
				-W1.5p,black -O -K >> "${ps_file}"
			gmt psxy "${work_dir}/ant_horizontal_outline.txt" -R -J \
				-W1.5p,black -O -K >> "${ps_file}"
		fi
	done
	gmt psscale -R -J -C"${velocity_cpt}" \
		-Dx-5.5i/-0.85i+w7.7i/0.13i+h -Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tf \
		-F"${script_dir}/ex17_cascadia_interpolation_horizontal"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/ex17_cascadia_interpolation_horizontal"
}

plot_vertical() {
	local ps_file="${work_dir}/ex17_vertical.ps"
	local names=(tiled merged aggregate)
	local titles=("Tiling" "Merging" "Aggregate")
	local letters=(a b c)
	for index in 0 1 2; do
		name=${names[index]}
		title="(${letters[index]}) ${titles[index]}: latitude = ${section_latitude} N"
		y_axis=-Bya20f10
		if ((index == 0)); then
			y_axis=-Bya20f10+l"Depth (km)"
			gmt grdimage "${work_dir}/${name}_vertical.nc" -P \
				-R${section_region} -J${section_projection} -C"${velocity_cpt}" \
				-Bxa5f1+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
				-fc -X0.45i -Y2.0i -K > "${ps_file}"
		else
			gmt grdimage "${work_dir}/${name}_vertical.nc" -R -J \
				-C"${velocity_cpt}" -Bxa5f1+l"Longitude" "${y_axis}" \
				"-BWSen+t${title}" -fc -X2.75i -O -K >> "${ps_file}"
		fi
		printf "%s %s\n%s %s\n" -130 "${section_depth}" -116 "${section_depth}" | \
			gmt psxy -R -J -W1.5p,black,-- -fc -O -K >> "${ps_file}"
		if ((index == 0)); then
			gmt psxy "${work_dir}/svi_vertical_outline.txt" -R -J \
				-W1.5p,black -fc -O -K >> "${ps_file}"
			gmt psxy "${work_dir}/ant_vertical_outline.txt" -R -J \
				-W1.5p,black -fc -O -K >> "${ps_file}"
		fi
	done
	gmt psscale -R -J -C"${velocity_cpt}" \
		-Dx-5.5i/-0.85i+w7.7i/0.13i+h -Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tf \
		-F"${script_dir}/ex17_cascadia_interpolation_vertical"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/ex17_cascadia_interpolation_vertical"
}

plot_horizontal
plot_vertical
