#!/usr/bin/env bash
#
# Merge Cascadia volumes inside polygons smaller than the primary grid domains.

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

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex19-cascadia.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

svi="${data_dir}/SVI_EQTOMO_Savard2018.r0.1.nc?Vs+Vkm/s"
ant_rf="${data_dir}/Cascadia-ANT+RF-Delph2018.r0.1.nc?Vs+Vkm/s"
wus324="${data_dir}/WUS324-Casc-CVM.r0.0-n4.nc?Vs+Vkm/s"
svi_slice="${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
ant_rf_slice="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
star="${work_dir}/svi_star.txt"
triangle="${work_dir}/ant_rf_triangle.txt"
tile_mergefile="${work_dir}/supported_tiling.merge3d"
mergefile="${work_dir}/polygon_supports.merge3d"
region=-130/-116/39/52
increment=0.05
zrange=0/60/1
section_depth=2
section_latitude=48
section_region=-130/-116/0/60
map_projection=M2.2i
vertical_projection=X2.2i/-1.7i
taper_ratios=0.49/0.49/0.49/0.49/0/0.49
velocity_cpt="${work_dir}/velocity.cpt"
colorbar_font=9.8p

# A four-pointed isotoxal star contained by SVI EQTOMO.
cat > "${star}" <<- EOF
	-123.55 50.70
	-124.20 49.60
	-125.80 48.95
	-124.20 48.30
	-123.55 47.20
	-122.90 48.30
	-121.30 48.95
	-122.90 49.60
	-123.55 50.70
	EOF

# A triangular support contained by Cascadia ANT+RF.
cat > "${triangle}" <<- EOF
	-124.70 40.20
	-120.10 46.00
	-124.70 48.90
	-124.70 40.20
	EOF

# Boxcar weights produce a hard first-availability tile inside each extruded
# polygon. The cosine merge uses no taper at the beginning of z.
cat > "${tile_mergefile}" <<- EOF
	${svi} ${wus324} ${star} - boxcar/boxcar/boxcar 0
	${ant_rf} ${wus324} ${triangle} - boxcar/boxcar/boxcar 0
	${wus324} - - - - -
	EOF
cat > "${mergefile}" <<- EOF
	${svi} ${wus324} ${star} - cosine/cosine/cosine ${taper_ratios}
	${ant_rf} ${wus324} ${triangle} - cosine/cosine/cosine ${taper_ratios}
	${wus324} - - - - -
	EOF

gmt merge3d "${tile_mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvs -Sl+g -P -G"${work_dir}/tiled.nc"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvs -Sl+g -P -G"${work_dir}/merged.nc"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvs -Sl+g -A -P -G"${work_dir}/aggregate.nc"

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

# Full-domain outlines for the two primaries.
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

# Intersections of the extruded polygons with latitude = 48 N.
cat > "${work_dir}/star_vertical_support.txt" <<- EOF
	-124.0227 0
	-123.0773 0
	-123.0773 60
	-124.0227 60
	-124.0227 0
	EOF
cat > "${work_dir}/triangle_vertical_support.txt" <<- EOF
	-124.7000 0
	-123.2724 0
	-123.2724 60
	-124.7000 60
	-124.7000 0
	EOF

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"

plot_horizontal() {
	local ps_file="${work_dir}/ex19_horizontal.ps"
	local names=(tiled merged aggregate)
	local titles=("Supported tiling" "Supported merging" "Aggregate merging")
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
			gmt psxy "${star}" -R -J -W1.5p,white,-- -O -K >> "${ps_file}"
			gmt psxy "${triangle}" -R -J -W1.5p,white,-- -O -K >> "${ps_file}"
		fi
	done
	gmt psscale -R -J -C"${velocity_cpt}" \
		-Dx-5.5i/-0.85i+w7.7i/0.13i+h -Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tf \
		-F"${script_dir}/ex19_cascadia_polygon_supports_horizontal"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/ex19_cascadia_polygon_supports_horizontal"
}

plot_vertical() {
	local ps_file="${work_dir}/ex19_vertical.ps"
	local names=(tiled merged aggregate)
	local titles=("Supported tiling" "Supported merging" "Aggregate merging")
	local letters=(a b c)
	for index in 0 1 2; do
		name=${names[index]}
		title="(${letters[index]}) ${titles[index]}: latitude = ${section_latitude} N"
		y_axis=-Bya20f10
		if ((index == 0)); then
			y_axis=-Bya20f10+l"Depth (km)"
			gmt grdimage "${work_dir}/${name}_vertical.nc" -P \
				-R${section_region} -J${vertical_projection} -C"${velocity_cpt}" \
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
			gmt psxy "${work_dir}/star_vertical_support.txt" -R -J \
				-W1.5p,white,-- -fc -O -K >> "${ps_file}"
			gmt psxy "${work_dir}/triangle_vertical_support.txt" -R -J \
				-W1.5p,white,-- -fc -O -K >> "${ps_file}"
		fi
	done
	gmt psscale -R -J -C"${velocity_cpt}" \
		-Dx-5.5i/-0.85i+w7.7i/0.13i+h -Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tf \
		-F"${script_dir}/ex19_cascadia_polygon_supports_vertical"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/ex19_cascadia_polygon_supports_vertical"
}

plot_horizontal
plot_vertical
