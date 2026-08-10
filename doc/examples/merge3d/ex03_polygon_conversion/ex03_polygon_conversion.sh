#!/usr/bin/env bash
#
# Convert a non-monotone polygon before merging two cubes.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex03-polygon.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=-85/-30/-60/15
increment=0.5
zrange=0/100/1
horizontal_projection=X1.45i/1.98i
vertical_projection=X1.45i/-1.98i
primary="${work_dir}/primary.nc"
secondary="${work_dir}/secondary.nc"
support="${script_dir}/south_america.txt"
converted="${script_dir}/south_america_monotone.txt"
mergefile="${work_dir}/polygon.merge3d"
merged="${work_dir}/merged.nc"
ps_file="${work_dir}/ex03_polygon_conversion.ps"
value_cpt="${work_dir}/values.cpt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=13.6p

# Build constant full-domain input cubes from their end layers.
for z in 0 100; do
	gmt grdmath -R${region} -I${increment} 8 = \
		"${work_dir}/primary_$(printf '%03d' "${z}").nc"
	gmt grdmath -R${region} -I${increment} 2 = \
		"${work_dir}/secondary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/primary_*.nc -Z0/100/100 -G"${primary}"
gmt grdinterpolate "${work_dir}"/secondary_*.nc -Z0/100/100 \
	-G"${secondary}"

# Limit the converted horizontal support to z = 20/80.
cat > "${mergefile}" <<- EOF
	${primary} ${secondary} ${support} 20/80 cosine/cosine/cosine 0.49
	${secondary} - - - - -
	EOF
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-ME+w -W -G"${merged}"
[[ -s "${converted}" ]]

# Horizontal slices at z = 50 and vertical sections along latitude -20.
gmt grdinterpolate "${primary}" -T50 -G"${work_dir}/primary_horizontal.nc"
gmt grdinterpolate "${secondary}" -T50 \
	-G"${work_dir}/secondary_horizontal.nc"
gmt grdconvert "${merged}?cube[50]" "${work_dir}/merged_horizontal.nc"
gmt grdconvert "${merged}?weight[50]" "${work_dir}/weight_horizontal.nc"
gmt grdcut "${merged}?cube" -Ey-20 -G"${work_dir}/merged_vertical.nc"
gmt grdcut "${merged}?weight" -Ey-20 -G"${work_dir}/weight_vertical.nc"

# Constant inputs make the expected result 2 + 6 * weight in both views.
for view in horizontal vertical; do
	gmt grdmath "${work_dir}/weight_${view}.nc" 6 MUL 2 ADD = \
		"${work_dir}/expected_${view}.nc"
	gmt grdmath "${work_dir}/merged_${view}.nc" \
		"${work_dir}/expected_${view}.nc" SUB = \
		"${work_dir}/difference_${view}.nc"
	gmt grdinfo "${work_dir}/difference_${view}.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
	gmt grdinfo "${work_dir}/weight_${view}.nc" -C | \
		awk '$6 < 0 || $7 > 1 {exit 1}'
done

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T2/8/1 -Z > "${value_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

plot_horizontal() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} -C"${cpt}" \
		-Bxa10f5+l"Longitude" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
}

plot_vertical() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R-85/-30/0/100 -J${vertical_projection} -C"${cpt}" \
		-Bxa10f5+l"Longitude" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
}

# Top row: inputs and horizontal support conversion.
gmt grdimage "${work_dir}/primary_horizontal.nc" -P -R${region} \
	-J${horizontal_projection} -C"${value_cpt}" -Bxa10f5+l"Longitude" \
	-Bya15f5+l"Latitude" -BWSen+t"(a) Primary: z = 50" \
	-X0.55i -Y4.75i -K > "${ps_file}"
gmt psxy "${support}" -R -J -L -W1p,white,- -O -K >> "${ps_file}"
printf "%s\n" "-85 -20" "-30 -20" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"

plot_horizontal "${work_dir}/secondary_horizontal.nc" "${value_cpt}" \
	"(b) Secondary: z = 50" 2.0i 0i -Bya15f5
gmt psxy "${support}" -R -J -L -W1p,white,- -O -K >> "${ps_file}"
printf "%s\n" "-85 -20" "-30 -20" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"

gmt psbasemap -R -J -Bxa10f5+l"Longitude" -Bya15f5 \
	-BWSen+t"(c) Input polygon" -X2.0i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"
printf "%s\n" "-85 -20" "-30 -20" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"

gmt psbasemap -R -J -Bxa10f5+l"Longitude" -Bya15f5 \
	-BWSen+t"(d) -ME envelope" -X2.0i -O -K >> "${ps_file}"
gmt psxy "${converted}" -R -J -L -W1.5p,black -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"

# Bottom row: horizontal and vertical views of the output.
plot_horizontal "${work_dir}/weight_horizontal.nc" "${weight_cpt}" \
	"(e) Weight: z = 50" -6.0i -2.85i -Bya15f5+lLatitude
gmt psxy "${converted}" -R -J -L -W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,royalblue,-- -O -K >> "${ps_file}"
printf "%s\n" "-85 -20" "-30 -20" | \
	gmt psxy -R -J -W1.5p,hotpink,-- -O -K >> "${ps_file}"

plot_horizontal "${work_dir}/merged_horizontal.nc" "${value_cpt}" \
	"(f) Merged: z = 50" 2.0i 0i -Bya15f5
gmt psxy "${converted}" -R -J -L -W1.5p,white -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,white,-- -O -K >> "${ps_file}"
printf "%s\n" "-85 -20" "-30 -20" | \
	gmt psxy -R -J -W1.5p,hotpink,-- -O -K >> "${ps_file}"

plot_vertical "${work_dir}/weight_vertical.nc" "${weight_cpt}" \
	"(g) Weight: y = -20" 2.0i 0i -Bya20f10+lZ
printf "> lower\n-85 20\n-30 20\n> upper\n-85 80\n-30 80\n" | \
	gmt psxy -R -J -W1.5p,orangered -O -K >> "${ps_file}"

plot_vertical "${work_dir}/merged_vertical.nc" "${value_cpt}" \
	"(h) Merged: y = -20" 2.0i 0i -Bya20f10
printf "> lower\n-85 20\n-30 20\n> upper\n-85 80\n-30 80\n" | \
	gmt psxy -R -J -W1.5p,white -O -K >> "${ps_file}"

gmt psscale -R -J -C"${weight_cpt}" \
	-Dx-6.0i/-0.75i+w3.15i/0.13i+h \
	-Bxa0.2f0.1+l"Merging weight" \
	--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
	-O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" \
	-Dx-2.0i/-0.75i+w3.15i/0.13i+h \
	-Bxa1f0.5+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A+m0.1i -Tf \
	-F"${script_dir}/ex03_polygon_conversion"
gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex03_polygon_conversion"
