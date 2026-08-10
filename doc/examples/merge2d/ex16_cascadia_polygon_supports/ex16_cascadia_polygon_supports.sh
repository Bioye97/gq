#!/usr/bin/env bash
#
# Merge Cascadia models within polygon supports smaller than their grid domains.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}
plot_depth_label() {
	printf "%s\n" "-116.25 39.3 2 km" | \
		gmt pstext -R -J -F+f10p,Helvetica,black+jBR -Gwhite -C0.08c -O -K
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prepare_script="${script_dir}/../../data/cascadia/prepare_vs_slices.sh"
if [[ -n "${GQ_EXAMPLE_DATA:-}" ]]; then
	data_dir="${GQ_EXAMPLE_DATA}/cascadia"
else
	data_dir="${script_dir}/../../data/cascadia"
fi
GMT="${gmt_executable}" "${prepare_script}"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex16-cascadia.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

svi="${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
ant_rf="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
wus324="${data_dir}/WUS324-Casc-Vs-2km.nc"
star="${work_dir}/svi_star.txt"
triangle="${work_dir}/ant_rf_triangle.txt"
mergefile="${work_dir}/polygon_supports.merge2d"
tiled="${work_dir}/tiled.nc"
merged="${work_dir}/merged.nc"
aggregate="${work_dir}/aggregate.nc"
svi_outline="${work_dir}/svi_outline.txt"
ant_rf_outline="${work_dir}/ant_rf_outline.txt"

region=-130/-116/39/52
increment=0.05
projection=M2.2i
ps_file="${work_dir}/ex16_cascadia_polygon_supports.ps"
velocity_cpt="${work_dir}/velocity.cpt"
colorbar_font=9.8p

# A four-pointed isotoxal star contained by the SVI EQTOMO grid.
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

# A triangular support contained by the Cascadia ANT+RF grid.
cat > "${triangle}" <<- EOF
	-124.70 40.20
	-120.10 46.00
	-124.70 48.90
	-124.70 40.20
	EOF

cat > "${mergefile}" <<- EOF
	${svi} ${wus324} ${star} cosine/cosine 0.2
	${ant_rf} ${wus324} ${triangle} cosine/cosine 0.2
	${wus324} - - - -
	EOF

# Build a first-availability tile constrained to the two polygon supports.
svi_prepared="${work_dir}/svi_prepared.nc"
ant_rf_prepared="${work_dir}/ant_rf_prepared.nc"
svi_mask="${work_dir}/svi_mask.nc"
ant_rf_mask="${work_dir}/ant_rf_mask.nc"
svi_clipped="${work_dir}/svi_clipped.nc"
ant_rf_clipped="${work_dir}/ant_rf_clipped.nc"
gmt merge2d "${svi}" "${svi}" -R${region} -I${increment} -Cf -Hl \
	-G"${svi_prepared}"
gmt merge2d "${ant_rf}" "${ant_rf}" -R${region} -I${increment} -Cf -Hl \
	-G"${ant_rf_prepared}"
gmt grdmask "${star}" -R${region} -I${increment} -NNaN/1/1 -G"${svi_mask}"
gmt grdmask "${triangle}" -R${region} -I${increment} \
	-NNaN/1/1 -G"${ant_rf_mask}"
gmt grdmath "${svi_prepared}" "${svi_mask}" MUL = "${svi_clipped}"
gmt grdmath "${ant_rf_prepared}" "${ant_rf_mask}" MUL = "${ant_rf_clipped}"
gmt merge2d "${svi_clipped}" "${ant_rf_clipped}" "${wus324}" \
	-R${region} -I${increment} -Cf -G"${tiled}"

# Interpolation precedes both regular and aggregate polygon-supported merging.
gmt merge2d "${mergefile}" -R${region} -I${increment} -Hl -P -G"${merged}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -Hl -A -P \
	-G"${aggregate}"

gmt grdmath "${merged}" "${tiled}" SUB = "${work_dir}/difference.nc"
gmt grdinfo "${work_dir}/difference.nc" -C | \
	awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
gmt grdmath "${aggregate}" "${merged}" SUB = \
	"${work_dir}/aggregate_difference.nc"
gmt grdinfo "${work_dir}/aggregate_difference.nc" -C | \
	awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'

gmt grdinfo "${svi}" -C | awk '{
	print $2, $4; print $3, $4; print $3, $5; print $2, $5; print $2, $4
}' > "${svi_outline}"
gmt grdinfo "${ant_rf}" -C | awk '{
	print $2, $4; print $3, $4; print $3, $5; print $2, $5; print $2, $4
}' > "${ant_rf_outline}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"

gmt grdimage "${tiled}" -P -R${region} -J${projection} \
	-C"${velocity_cpt}" -Bxa5f1+l"Longitude" -Bya5f1+l"Latitude" \
	-BWSen+t"(a) Supported tiling" -X0.45i -Y2.0i -K > "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
gmt psxy "${svi_outline}" -R -J -W1.5p,black -O -K >> "${ps_file}"
gmt psxy "${ant_rf_outline}" -R -J -W1.5p,black -O -K >> "${ps_file}"
gmt psxy "${star}" -R -J -W1.5p,white,-- -O -K >> "${ps_file}"
gmt psxy "${triangle}" -R -J -W1.5p,white,-- -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"

gmt grdimage "${merged}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1 -BWSen+t"(b) Supported merging" \
	-X2.75i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"

gmt grdimage "${aggregate}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1 -BWSen+t"(c) Aggregate merging" \
	-X2.75i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"
gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-5.5i/-0.7i+w7.7i/0.13i+h \
	-Bxa1f0.5+l"Vs (km/s)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex16_cascadia_polygon_supports"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex16_cascadia_polygon_supports"
