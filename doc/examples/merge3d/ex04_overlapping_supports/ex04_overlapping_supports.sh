#!/usr/bin/env bash
#
# Normalize overlapping 3-D primary supports with merge3d -A.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex04-overlap.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=0/100/0/100
increment=1
zrange=0/100/1
horizontal_projection=X1.45i/1.45i
vertical_projection=X1.45i/-1.45i
primary1="${work_dir}/primary1.nc"
primary2="${work_dir}/primary2.nc"
secondary="${work_dir}/secondary.nc"
weight1="${work_dir}/weight1.nc"
weight2="${work_dir}/weight2.nc"
mergefile="${work_dir}/overlap.merge3d"
tiled="${work_dir}/tiled.nc"
regular="${work_dir}/regular.nc"
aggregate="${work_dir}/aggregate.nc"
ps_file="${work_dir}/ex04_overlapping_supports.ps"
value_cpt="${work_dir}/values.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=8.9p

# Primary 1 occupies x = 10/65, y = 15/85, and z = 10/80.
for z in 10 80; do
	gmt grdmath -R10/65/15/85 -I${increment} 8 = \
		"${work_dir}/primary1_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/primary1_*.nc -Z10/80/70 \
	-G"${primary1}"

# Primary 2 is offset in x and z, creating a three-dimensional overlap.
for z in 20 90; do
	gmt grdmath -R35/90/15/85 -I${increment} 5 = \
		"${work_dir}/primary2_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/primary2_*.nc -Z20/90/70 \
	-G"${primary2}"

# The secondary fills the complete output volume.
for z in 0 100; do
	gmt grdmath -R${region} -I${increment} 2 = \
		"${work_dir}/secondary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/secondary_*.nc -Z0/100/100 \
	-G"${secondary}"

# Generate each raw primary support weight independently.
cat > "${work_dir}/primary1.merge3d" <<- EOF
	${primary1} ${secondary} - - cosine/cosine/cosine 0.25
	${secondary} - - - - -
	EOF
cat > "${work_dir}/primary2.merge3d" <<- EOF
	${primary2} ${secondary} - - cosine/cosine/cosine 0.25
	${secondary} - - - - -
	EOF
gmt merge3d "${work_dir}/primary1.merge3d" -R${region} -I${increment} \
	-T${zrange} -W+o -G"${weight1}"
gmt merge3d "${work_dir}/primary2.merge3d" -R${region} -I${increment} \
	-T${zrange} -W+o -G"${weight2}"

# Compare first-available tiling, regular merging, and aggregate merging.
gmt merge3d "${primary1}" "${primary2}" "${secondary}" \
	-R${region} -I${increment} -T${zrange} -G"${tiled}"
cat > "${mergefile}" <<- EOF
	${primary1} ${secondary} - - cosine/cosine/cosine 0.25
	${primary2} ${secondary} - - cosine/cosine/cosine 0.25
	${secondary} - - - - -
	EOF
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-G"${regular}"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-A -W -G"${aggregate}"

# Extract horizontal slices at z = 50.
for name in tiled regular aggregate; do
	gmt grdconvert "${work_dir}/${name}.nc?cube[50]" \
		"${work_dir}/${name}_horizontal.nc"
done
gmt grdconvert "${weight1}?weight[50]" "${work_dir}/weight1_horizontal.nc"
gmt grdconvert "${weight2}?weight[50]" "${work_dir}/weight2_horizontal.nc"

# Extract vertical sections along y = 50.
for name in tiled regular aggregate; do
	gmt grdcut "${work_dir}/${name}.nc?cube" -Ey50 \
		-G"${work_dir}/${name}_vertical.nc"
done
gmt grdcut "${weight1}?weight" -Ey50 -G"${work_dir}/weight1_vertical.nc"
gmt grdcut "${weight2}?weight" -Ey50 -G"${work_dir}/weight2_vertical.nc"

# Reconstruct the aggregate result from normalized primary and background
# contributions, then confirm that -A changes the regular result.
for view in horizontal vertical; do
	gmt grdmath "${work_dir}/weight1_${view}.nc" \
		"${work_dir}/weight2_${view}.nc" ADD = \
		"${work_dir}/weight_sum_${view}.nc"
	gmt grdmath 1 "${work_dir}/weight_sum_${view}.nc" SUB 0 MAX = \
		"${work_dir}/background_weight_${view}.nc"
	gmt grdmath "${work_dir}/weight_sum_${view}.nc" \
		"${work_dir}/background_weight_${view}.nc" ADD = \
		"${work_dir}/weight_total_${view}.nc"
	gmt grdmath "${work_dir}/weight1_${view}.nc" 8 MUL \
		"${work_dir}/weight2_${view}.nc" 5 MUL ADD \
		"${work_dir}/background_weight_${view}.nc" 2 MUL ADD \
		"${work_dir}/weight_total_${view}.nc" DIV = \
		"${work_dir}/expected_${view}.nc"
	gmt grdmath "${work_dir}/aggregate_${view}.nc" \
		"${work_dir}/expected_${view}.nc" SUB = \
		"${work_dir}/aggregate_error_${view}.nc"
	gmt grdinfo "${work_dir}/aggregate_error_${view}.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
	gmt grdmath "${work_dir}/aggregate_${view}.nc" \
		"${work_dir}/regular_${view}.nc" SUB = \
		"${work_dir}/difference_${view}.nc"
	gmt grdinfo "${work_dir}/difference_${view}.nc" -C | \
		awk '$6 >= -1e-3 && $7 <= 1e-3 {exit 1}'
done

cat > "${work_dir}/primary1_horizontal.txt" <<- EOF
	10 15
	65 15
	65 85
	10 85
	10 15
	EOF
cat > "${work_dir}/primary2_horizontal.txt" <<- EOF
	35 15
	90 15
	90 85
	35 85
	35 15
	EOF
cat > "${work_dir}/primary1_vertical.txt" <<- EOF
	10 10
	65 10
	65 80
	10 80
	10 10
	EOF
cat > "${work_dir}/primary2_vertical.txt" <<- EOF
	35 20
	90 20
	90 90
	35 90
	35 20
	EOF

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T2/8/1 -Z > "${value_cpt}"

plot_horizontal() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 yaxis=$5
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} \
		-C"${value_cpt}" -Bxa20f10+l"X" "${yaxis}" \
		"-BWSen+t${title}" -X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/primary1_horizontal.txt" -R -J \
		-W1.5p,royalblue,- -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/primary2_horizontal.txt" -R -J \
		-W1.5p,orangered,- -O -K >> "${ps_file}"
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
}

plot_vertical() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 yaxis=$5
	gmt grdimage "${grid}" -R${region} -J${vertical_projection} \
		-C"${value_cpt}" -Bxa20f10+l"X" "${yaxis}" \
		"-BWSen+t${title}" -X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/primary1_vertical.txt" -R -J \
		-W1.5p,royalblue,- -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/primary2_vertical.txt" -R -J \
		-W1.5p,orangered,- -O -K >> "${ps_file}"
}

# Top row: horizontal supports and outputs at z = 50.
gmt psbasemap -P -R${region} -J${horizontal_projection} \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(a) Horizontal supports" \
	-X0.55i -Y4.05i -K > "${ps_file}"
gmt psxy "${work_dir}/primary1_horizontal.txt" -R -J \
	-Glightsteelblue -W1.5p,royalblue -t25 -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary2_horizontal.txt" -R -J \
	-Glightsalmon -W1.5p,orangered -t25 -O -K >> "${ps_file}"
printf "24 55 Primary 1 = 8\n76 55 Primary 2 = 5\n50 7 Secondary = 2\n" | \
	gmt pstext -R -J -F+f7p,Helvetica,black+jCM -O -K >> "${ps_file}"
printf "0 50\n100 50\n" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"

plot_horizontal "${work_dir}/tiled_horizontal.nc" "(b) Tiling: z = 50" \
	2.0i 0i -Bya20f10
plot_horizontal "${work_dir}/regular_horizontal.nc" "(c) Regular: z = 50" \
	2.0i 0i -Bya20f10
plot_horizontal "${work_dir}/aggregate_horizontal.nc" \
	"(d) Aggregate: z = 50" 2.0i 0i -Bya20f10

# Bottom row: vertical supports and outputs along y = 50.
gmt psbasemap -R${region} -J${vertical_projection} \
	-Bxa20f10+l"X" -Bya20f10+l"Z" -BWSen+t"(e) Vertical supports" \
	-X-6.0i -Y-2.35i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary1_vertical.txt" -R -J \
	-Glightsteelblue -W1.5p,royalblue -t25 -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary2_vertical.txt" -R -J \
	-Glightsalmon -W1.5p,orangered -t25 -O -K >> "${ps_file}"
printf "24 48 Primary 1 = 8\n76 55 Primary 2 = 5\n50 96 Secondary = 2\n" | \
	gmt pstext -R -J -F+f7p,Helvetica,black+jCM -O -K >> "${ps_file}"

plot_vertical "${work_dir}/tiled_vertical.nc" "(f) Tiling: y = 50" \
	2.0i 0i -Bya20f10
plot_vertical "${work_dir}/regular_vertical.nc" "(g) Regular: y = 50" \
	2.0i 0i -Bya20f10
plot_vertical "${work_dir}/aggregate_vertical.nc" \
	"(h) Aggregate: y = 50" 2.0i 0i -Bya20f10

gmt psscale -R -J -C"${value_cpt}" \
	-Dx-6.0i/-0.75i+w7.45i/0.13i+h \
	-Bxa1f0.5+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A+m0.1i -Tf \
	-F"${script_dir}/ex04_overlapping_supports"
gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex04_overlapping_supports"
