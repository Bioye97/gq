#!/usr/bin/env bash
#
# Limit vertical gap bridging by the bracketing z-coordinate distance.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
ncgen_executable=${NCGEN:-$(command -v ncgen || true)}
if [[ -z "${ncgen_executable}" ]]; then
	echo "ncgen was not found; set NCGEN=/path/to/ncgen" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex08-limits.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=0/100/0/100
increment=2
zrange=0/100/1
horizontal_projection=X1.45i/1.45i
vertical_projection=X1.45i/-1.45i
model_cdl="${work_dir}/model.cdl"
model_nc="${work_dir}/model.nc"
ps_file="${work_dir}/ex08_gap_limits.ps"
value_cpt="${work_dir}/values.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=8.9p

# Remove two internal cylinders with different vertical spans and one cylinder
# connected to z = 0 from a smooth reference model.
awk 'BEGIN {
	xmin = 0; xmax = 100; ymin = 0; ymax = 100
	zmin = 0; zmax = 100; inc = 2; zinc = 2
	nx = (xmax - xmin) / inc + 1
	ny = (ymax - ymin) / inc + 1
	nz = (zmax - zmin) / zinc + 1
	n = nx * ny * nz
	print "netcdf model {"
	print "dimensions:"
	printf "\tz = %d ;\n\ty = %d ;\n\tx = %d ;\n", nz, ny, nx
	print "variables:"
	print "\tdouble z(z) ;"
	print "\t\tz:axis = \"Z\" ;"
	print "\t\tz:units = \"km\" ;"
	print "\tdouble y(y) ;"
	print "\t\ty:axis = \"Y\" ;"
	print "\t\ty:units = \"km\" ;"
	print "\tdouble x(x) ;"
	print "\t\tx:axis = \"X\" ;"
	print "\t\tx:units = \"km\" ;"
	print "\tfloat reference(z, y, x) ;"
	print "\t\treference:long_name = \"complete reference field\" ;"
	print "\tfloat gapped(z, y, x) ;"
	print "\t\tgapped:_FillValue = -99999.f ;"
	print "\t\tgapped:long_name = \"field with limited and edge gaps\" ;"
	print "data:"
	printf "\tz = "
	for (k = 0; k < nz; k++) printf "%g%s", zmin + k * zinc, (k == nz - 1 ? " ;\n" : ", ")
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%g%s", ymin + j * inc, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%g%s", xmin + i * inc, (i == nx - 1 ? " ;\n" : ", ")
	printf "\treference ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * zinc
		v = 5 + 0.008 * x + 0.004 * y + 0.006 * z + 0.6 * sin(x / 14) * cos(y / 18) + 0.5 * sin(z / 13)
		printf "%s%.7g%s", (q % 10 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	printf "\tgapped ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * zinc
		small = ((x - 20)^2 + (y - 50)^2 <= 8^2 && z >= 44 && z <= 56)
		large = ((x - 56)^2 + (y - 50)^2 <= 14^2 && z >= 30 && z <= 70)
		edge = ((x - 86)^2 + (y - 50)^2 <= 8^2 && z >= 0 && z <= 20)
		missing = small || large || edge
		v = missing ? -99999 : 5 + 0.008 * x + 0.004 * y + 0.006 * z + 0.6 * sin(x / 14) * cos(y / 18) + 0.5 * sin(z / 13)
		printf "%s%.7g%s", (q % 10 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	print "}"
}' > "${model_cdl}"

"${ncgen_executable}" -4 -o "${model_nc}" "${model_cdl}"

# A 20 km limit accepts the small 16 km bracket and rejects the large 44 km
# bracket. The edge-connected gap cannot be filled without extrapolation.
gmt merge3d "${model_nc}?reference" -R${region} -I${increment} \
	-T${zrange} -Fvalue -Sl -nl -G"${work_dir}/reference.nc"
gmt merge3d "${model_nc}?gapped" -R${region} -I${increment} \
	-T${zrange} -Fvalue -Sl -nl -G"${work_dir}/gapped.nc"
gmt merge3d "${model_nc}?gapped" -R${region} -I${increment} \
	-T${zrange} -Fvalue -Sl+g20 -nl -G"${work_dir}/limited.nc"
gmt merge3d "${model_nc}?gapped" -R${region} -I${increment} \
	-T${zrange} -Fvalue -Sl+g -nl -G"${work_dir}/unlimited.nc"

# Extract horizontal slices at z = 50 and vertical sections along y = 50.
for name in reference gapped limited unlimited; do
	gmt grdconvert "${work_dir}/${name}.nc?value[50]" \
		"${work_dir}/${name}_horizontal.nc"
	gmt grdcut "${work_dir}/${name}.nc?value" -Ey50 \
		-G"${work_dir}/${name}_vertical.nc"
done

# Check the small, large, and edge-connected gaps at their centers.
for view in horizontal vertical; do
	if [[ ${view} == horizontal ]]; then
		printf "20 50\n56 50\n" > "${work_dir}/sample_points.txt"
	else
		printf "20 50\n56 50\n" > "${work_dir}/sample_points.txt"
	fi
	gmt grdtrack "${work_dir}/sample_points.txt" \
		-G"${work_dir}/gapped_${view}.nc" > "${work_dir}/gapped_${view}_samples.txt"
	gmt grdtrack "${work_dir}/sample_points.txt" \
		-G"${work_dir}/limited_${view}.nc" > "${work_dir}/limited_${view}_samples.txt"
	gmt grdtrack "${work_dir}/sample_points.txt" \
		-G"${work_dir}/unlimited_${view}.nc" > "${work_dir}/unlimited_${view}_samples.txt"
	awk 'tolower($3) != "nan" {exit 1}' "${work_dir}/gapped_${view}_samples.txt"
	awk 'NR == 1 && tolower($3) == "nan" {exit 1}
		 NR == 2 && tolower($3) != "nan" {exit 1}' \
		"${work_dir}/limited_${view}_samples.txt"
	awk 'tolower($3) == "nan" {exit 1}' "${work_dir}/unlimited_${view}_samples.txt"
done
printf "86 10\n" | gmt grdtrack -G"${work_dir}/gapped_vertical.nc" \
	-G"${work_dir}/limited_vertical.nc" -G"${work_dir}/unlimited_vertical.nc" \
	> "${work_dir}/edge_samples.txt"
awk '{for (column = 3; column <= NF; column++) if (tolower($column) != "nan") exit 1}' \
	"${work_dir}/edge_samples.txt"

# Outlines of the two internal cylinders in the horizontal slice.
for specification in "small 20 8" "large 56 14"; do
	read -r name center radius <<< "${specification}"
	awk -v center="${center}" -v radius="${radius}" 'BEGIN {
		pi = atan2(0, -1)
		for (angle = 0; angle <= 360; angle += 2) {
			radians = angle * pi / 180
			print center + radius * cos(radians), 50 + radius * sin(radians)
		}
	}' > "${work_dir}/${name}_horizontal.txt"
done
cat > "${work_dir}/small_vertical.txt" <<- EOF
	12 44
	28 44
	28 56
	12 56
	12 44
	EOF
cat > "${work_dir}/large_vertical.txt" <<- EOF
	42 30
	70 30
	70 70
	42 70
	42 30
	EOF
cat > "${work_dir}/edge_vertical.txt" <<- EOF
	78 0
	94 0
	94 20
	78 20
	78 0
	EOF

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T4/8/0.25 -Z > "${value_cpt}"

draw_horizontal_outlines() {
	gmt psxy "${work_dir}/small_horizontal.txt" -R -J \
		-W1.5p,royalblue,- -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/large_horizontal.txt" -R -J \
		-W1.5p,orangered,- -O -K >> "${ps_file}"
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
}

draw_vertical_outlines() {
	gmt psxy "${work_dir}/small_vertical.txt" -R -J \
		-W1.5p,royalblue,- -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/large_vertical.txt" -R -J \
		-W1.5p,orangered,- -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/edge_vertical.txt" -R -J \
		-W1.5p,black,- -O -K >> "${ps_file}"
}

plot_horizontal() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 yaxis=$5
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} \
		-C"${value_cpt}" -Bxa20f10+l"X (km)" "${yaxis}" \
		"-BWSen+t${title}" -X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	draw_horizontal_outlines
}

plot_vertical() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 yaxis=$5
	gmt grdimage "${grid}" -R${region} -J${vertical_projection} \
		-C"${value_cpt}" -Bxa20f10+l"X (km)" "${yaxis}" \
		"-BWSen+t${title}" -X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	draw_vertical_outlines
}

# Top row: horizontal slices through both internal gaps at z = 50.
gmt grdimage "${work_dir}/reference_horizontal.nc" -P -R${region} \
	-J${horizontal_projection} -C"${value_cpt}" -Bxa20f10+l"X (km)" \
	-Bya20f10+l"Y (km)" -BWSen+t"(a) Reference: z = 50" \
	-X0.55i -Y4.05i -K > "${ps_file}"
draw_horizontal_outlines
plot_horizontal "${work_dir}/gapped_horizontal.nc" "(b) Gapped: z = 50" \
	2.0i 0i -Bya20f10
plot_horizontal "${work_dir}/limited_horizontal.nc" "(c) Limited: z = 50" \
	2.0i 0i -Bya20f10
plot_horizontal "${work_dir}/unlimited_horizontal.nc" "(d) Unlimited: z = 50" \
	2.0i 0i -Bya20f10

# Bottom row: vertical sections show the edge-connected gap as well.
plot_vertical "${work_dir}/reference_vertical.nc" "(e) Reference: y = 50" \
	-6.0i -2.35i -Bya20f10+l"Z (km)"
plot_vertical "${work_dir}/gapped_vertical.nc" "(f) Gapped: y = 50" \
	2.0i 0i -Bya20f10
plot_vertical "${work_dir}/limited_vertical.nc" "(g) Limited: y = 50" \
	2.0i 0i -Bya20f10
plot_vertical "${work_dir}/unlimited_vertical.nc" "(h) Unlimited: y = 50" \
	2.0i 0i -Bya20f10

gmt psscale -R -J -C"${value_cpt}" -Dx-6.0i/-0.75i+w7.45i/0.13i+h \
	-Bxa0.5f0.25+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A+m0.1i -Tf \
	-F"${script_dir}/ex08_gap_limits"
gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex08_gap_limits"
