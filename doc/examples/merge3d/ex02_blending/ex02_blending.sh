#!/usr/bin/env bash
#
# Merge a primary cube with a secondary cube using a 3-D cosine taper.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex02-blending.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=0/100/0/100
increment=1
zrange=0/100/1
horizontal_projection=X1.45i/1.45i
vertical_projection=X1.45i/-1.45i
primary="${work_dir}/primary.nc"
secondary="${work_dir}/secondary.nc"
mergefile="${work_dir}/blend.merge3d"
merged="${work_dir}/merged.nc"
ps_file="${work_dir}/ex02_blending.ps"
value_cpt="${work_dir}/values.cpt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=13.6p

# The primary occupies 20/80 along all three axes.
for ((z = 20; z <= 80; z += 5)); do
	gmt grdmath -R20/80/20/80 -I${increment} \
		X 50 SUB 12 DIV 2 POW Y 50 SUB 15 DIV 2 POW ADD NEG EXP 4 MUL \
		X 8 DIV SIN 0.5 MUL ADD ${z} 0.03 MUL ADD 5 ADD = \
		"${work_dir}/primary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/primary_*.nc -Z20/80/5 -G"${primary}"

# The secondary and output occupy 0/100 along all three axes.
for ((z = 0; z <= 100; z += 5)); do
	gmt grdmath -R${region} -I${increment} \
		X 40 DIV Y 50 DIV ADD X 15 DIV COS Y 18 DIV SIN MUL 0.6 MUL ADD \
		${z} 0.02 MUL ADD 2 ADD = \
		"${work_dir}/secondary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/secondary_*.nc -Z0/100/5 \
	-G"${secondary}"

# The omitted polygon and z range use the complete primary-cube support.
cat > "${mergefile}" <<- EOF
	${primary} ${secondary} - - cosine/cosine/cosine 0.25
	${secondary} - - - - -
	EOF
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} -W \
	-G"${merged}"

# Horizontal slices at z = 50.
gmt grdinterpolate "${primary}" -T50 -G"${work_dir}/primary_horizontal.nc"
gmt grdinterpolate "${secondary}" -T50 \
	-G"${work_dir}/secondary_horizontal.nc"
gmt grdconvert "${merged}?cube[50]" "${work_dir}/merged_horizontal.nc"
gmt grdconvert "${merged}?weight[50]" "${work_dir}/weight_horizontal.nc"

# Vertical sections along y = 50.
gmt grdcut "${primary}" -Ey50 -G"${work_dir}/primary_vertical.nc"
gmt grdcut "${secondary}" -Ey50 -G"${work_dir}/secondary_vertical.nc"
gmt grdcut "${merged}?cube" -Ey50 -G"${work_dir}/merged_vertical.nc"
gmt grdcut "${merged}?weight" -Ey50 -G"${work_dir}/weight_vertical.nc"

# Verify the weighted combination throughout the primary support.
for name in secondary merged weight; do
	gmt grdcut "${work_dir}/${name}_horizontal.nc" -R20/80/20/80 \
		-G"${work_dir}/${name}_support_horizontal.nc"
done
gmt grdmath "${work_dir}/weight_support_horizontal.nc" \
	"${work_dir}/primary_horizontal.nc" MUL \
	1 "${work_dir}/weight_support_horizontal.nc" SUB \
	"${work_dir}/secondary_support_horizontal.nc" MUL ADD = \
	"${work_dir}/expected_horizontal.nc"
gmt grdmath "${work_dir}/merged_support_horizontal.nc" \
	"${work_dir}/expected_horizontal.nc" SUB = \
	"${work_dir}/difference_horizontal.nc"
gmt grdinfo "${work_dir}/difference_horizontal.nc" -C | \
	awk '$6 < -1e-5 || $7 > 1e-5 {
		printf "Weighted-combination difference: %g/%g\n", $6, $7 > "/dev/stderr"
		exit 1
	}'
for view in horizontal vertical; do
	gmt grdinfo "${work_dir}/weight_${view}.nc" -C | \
		awk '$6 < 0 || $7 > 1 {exit 1}'
done

cat > "${work_dir}/support_outline.txt" <<- EOF
	20 20
	80 20
	80 80
	20 80
	20 20
	EOF
cat > "${work_dir}/full_weight_outline.txt" <<- EOF
	35 35
	65 35
	65 65
	35 65
	35 35
	EOF

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T1/12/1 -Z > "${value_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

plot_horizontal() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} -C"${cpt}" \
		-Bxa20f10+l"X" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
}

plot_horizontal_hotpink() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} -C"${cpt}" \
		-Bxa20f10+l"X" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.5p,hotpink,-- -O -K >> "${ps_file}"
}

plot_vertical() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${vertical_projection} -C"${cpt}" \
		-Bxa20f10+l"X" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
}

# Top row: horizontal slices at z = 50.
gmt grdimage "${work_dir}/primary_horizontal.nc" -P -R${region} \
	-J${horizontal_projection} -C"${value_cpt}" -Bxa20f10+l"X" \
	-Bya20f10+l"Y" -BWSen+t"(a) Primary: z = 50" \
	-X0.55i -Y4.05i -K > "${ps_file}"
printf "0 50\n100 50\n" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
plot_horizontal "${work_dir}/secondary_horizontal.nc" "${value_cpt}" \
	"(b) Secondary: z = 50" 2.0i 0i -Bya20f10
plot_horizontal_hotpink "${work_dir}/weight_horizontal.nc" "${weight_cpt}" \
	"(c) Merging weight: z = 50" 2.0i 0i -Bya20f10
gmt psxy "${work_dir}/support_outline.txt" -R -J -W1p,orangered,- \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/full_weight_outline.txt" -R -J -W1p,royalblue,- \
	-O -K >> "${ps_file}"
plot_horizontal "${work_dir}/merged_horizontal.nc" "${value_cpt}" \
	"(d) Merged: z = 50" 2.0i 0i -Bya20f10

# Bottom row: vertical sections along y = 50.
plot_vertical "${work_dir}/primary_vertical.nc" "${value_cpt}" \
	"(e) Primary: y = 50" -6.0i -2.35i -Bya20f10+lZ
plot_vertical "${work_dir}/secondary_vertical.nc" "${value_cpt}" \
	"(f) Secondary: y = 50" 2.0i 0i -Bya20f10
plot_vertical "${work_dir}/weight_vertical.nc" "${weight_cpt}" \
	"(g) Merging weight: y = 50" 2.0i 0i -Bya20f10
gmt psxy "${work_dir}/support_outline.txt" -R -J -W1p,orangered,- \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/full_weight_outline.txt" -R -J -W1p,royalblue,- \
	-O -K >> "${ps_file}"
plot_vertical "${work_dir}/merged_vertical.nc" "${value_cpt}" \
	"(h) Merged: y = 50" 2.0i 0i -Bya20f10

gmt psscale -R -J -C"${weight_cpt}" \
	-Dx-6.0i/-0.75i+w3.15i/0.13i+h \
	-Bxa0.2f0.1+l"Merging weight" \
	--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
	-O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" \
	-Dx-2.0i/-0.75i+w3.15i/0.13i+h \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A+m0.1i -Tf -F"${script_dir}/ex02_blending"
gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex02_blending"
