#!/usr/bin/env bash
#
# Compare vertical methods for filling an internal spherical model gap.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex07-gaps.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=0/100/0/100
increment=2
zrange=0/100/1
horizontal_projection=X1.45i/1.45i
vertical_projection=X1.45i/-1.45i
model_cdl="${work_dir}/model.cdl"
model_nc="${work_dir}/model.nc"
horizontal_ps="${work_dir}/ex07_gap_methods_horizontal.ps"
vertical_ps="${work_dir}/ex07_gap_methods_vertical.ps"
value_cpt="${work_dir}/values.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=8.9p

# A spherical gap of radius 18 is removed from a smooth reference volume.
awk 'BEGIN {
	xmin = 0; xmax = 100; ymin = 0; ymax = 100
	zmin = 0; zmax = 100; inc = 2; zinc = 5
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
	print "\t\tgapped:long_name = \"field with spherical gap\" ;"
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
		local = exp(-((x - 50)^2 + (y - 50)^2) / 500)
		v = 5 + 0.008 * x + 0.004 * y + 0.7 * sin(x / 15) * cos(y / 17) + local * (0.005 * z + 0.8 * sin(z / 11) + 0.3 * cos(z / 20))
		printf "%s%.7g%s", (q % 10 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	printf "\tgapped ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * zinc
		missing = ((x - 50)^2 + (y - 50)^2 + (z - 50)^2 <= 18^2)
		local = exp(-((x - 50)^2 + (y - 50)^2) / 500)
		v = missing ? -99999 : 5 + 0.008 * x + 0.004 * y + 0.7 * sin(x / 15) * cos(y / 17) + local * (0.005 * z + 0.8 * sin(z / 11) + 0.3 * cos(z / 20))
		printf "%s%.7g%s", (q % 10 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	print "}"
}' > "${model_cdl}"

"${ncgen_executable}" -4 -o "${model_nc}" "${model_cdl}"

names=(akima cubic step linear nearest smoothing)
options=(-Sa+g -Sc+g -Se+g -Sl+g -Sn+g -Ss0.25+g)
titles=("Akima (-Sa)" "Cubic (-Sc)" "Step (-Se)" \
	"Linear (-Sl)" "Nearest (-Sn)" "Smoothing (-Ss0.25)")

# The first two outputs provide the complete and unfilled references.
gmt merge3d "${model_nc}?reference" -R${region} -I${increment} \
	-T${zrange} -Fvalue -Sl -nl -G"${work_dir}/reference.nc"
gmt merge3d "${model_nc}?gapped" -R${region} -I${increment} \
	-T${zrange} -Fvalue -Sl -nl -G"${work_dir}/gapped.nc"

for ((index = 0; index < ${#names[@]}; index++)); do
	name=${names[index]}
	gmt merge3d "${model_nc}?gapped" -R${region} -I${increment} \
		-T${zrange} -Fvalue -nl "${options[index]}" \
		-G"${work_dir}/${name}.nc"
done

# Extract horizontal slices at z = 50 and vertical sections along y = 50.
views=(reference gapped "${names[@]}")
for name in "${views[@]}"; do
	gmt grdconvert "${work_dir}/${name}.nc?value[50]" \
		"${work_dir}/${name}_horizontal.nc"
	gmt grdcut "${work_dir}/${name}.nc?value" -Ey50 \
		-G"${work_dir}/${name}_vertical.nc"
done

# The original gap remains missing without +g and is filled by every method.
for view in horizontal vertical; do
	printf "50 50\n" | gmt grdtrack -G"${work_dir}/gapped_${view}.nc" | \
		awk 'tolower($3) != "nan" {exit 1}'
	for name in "${names[@]}"; do
		gmt grdmath "${work_dir}/${name}_${view}.nc" ISNAN = \
			"${work_dir}/${name}_${view}_missing.nc"
		gmt grdinfo "${work_dir}/${name}_${view}_missing.nc" -C | \
			awk '$7 != 0 {exit 1}'
	done
done

# Confirm that every pair of methods produces a distinct reconstruction.
for ((first = 0; first < ${#names[@]}; first++)); do
	for ((second = first + 1; second < ${#names[@]}; second++)); do
		name1=${names[first]}
		name2=${names[second]}
		gmt grdmath "${work_dir}/${name1}_vertical.nc" \
			"${work_dir}/${name2}_vertical.nc" SUB = \
			"${work_dir}/${name1}_${name2}_difference.nc"
		gmt grdinfo "${work_dir}/${name1}_${name2}_difference.nc" -C | \
			awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
	done
done

# The sphere appears as a circle in both central cross-sections.
awk 'BEGIN {
	pi = atan2(0, -1)
	for (angle = 0; angle <= 360; angle += 2) {
		radians = angle * pi / 180
		print 50 + 18 * cos(radians), 50 + 18 * sin(radians)
	}
}' > "${work_dir}/gap_circle.txt"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T3/9/0.5 -Z > "${value_cpt}"

plot_horizontal() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 yaxis=$5 target=$6
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} \
		-C"${value_cpt}" -Bxa20f10+l"X (km)" "${yaxis}" \
		"-BWSen+t${title}" -X${xshift} -Y${yshift} -O -K >> "${target}"
	gmt psxy "${work_dir}/gap_circle.txt" -R -J \
		-W1.5p,royalblue,- -O -K >> "${target}"
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.5p,black,-- -O -K >> "${target}"
}

plot_vertical() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 yaxis=$5 target=$6
	gmt grdimage "${grid}" -R${region} -J${vertical_projection} \
		-C"${value_cpt}" -Bxa20f10+l"X (km)" "${yaxis}" \
		"-BWSen+t${title}" -X${xshift} -Y${yshift} -O -K >> "${target}"
	gmt psxy "${work_dir}/gap_circle.txt" -R -J \
		-W1.5p,royalblue,- -O -K >> "${target}"
}

# Horizontal figure at z = 50.
gmt grdimage "${work_dir}/reference_horizontal.nc" -P -R${region} \
	-J${horizontal_projection} -C"${value_cpt}" -Bxa20f10+l"X (km)" \
	-Bya20f10+l"Y (km)" -BWSen+t"(a) Reference" \
	-X0.55i -Y4.05i -K > "${horizontal_ps}"
gmt psxy "${work_dir}/gap_circle.txt" -R -J \
	-W1.5p,royalblue,- -O -K >> "${horizontal_ps}"
printf "0 50\n100 50\n" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${horizontal_ps}"
plot_horizontal "${work_dir}/gapped_horizontal.nc" "(b) Gapped" \
	2.0i 0i -Bya20f10 "${horizontal_ps}"
plot_horizontal "${work_dir}/akima_horizontal.nc" "(c) ${titles[0]}" \
	2.0i 0i -Bya20f10 "${horizontal_ps}"
plot_horizontal "${work_dir}/cubic_horizontal.nc" "(d) ${titles[1]}" \
	2.0i 0i -Bya20f10 "${horizontal_ps}"
plot_horizontal "${work_dir}/step_horizontal.nc" "(e) ${titles[2]}" \
	-6.0i -2.35i -Bya20f10+l"Y (km)" "${horizontal_ps}"
plot_horizontal "${work_dir}/linear_horizontal.nc" "(f) ${titles[3]}" \
	2.0i 0i -Bya20f10 "${horizontal_ps}"
plot_horizontal "${work_dir}/nearest_horizontal.nc" "(g) ${titles[4]}" \
	2.0i 0i -Bya20f10 "${horizontal_ps}"
plot_horizontal "${work_dir}/smoothing_horizontal.nc" "(h) ${titles[5]}" \
	2.0i 0i -Bya20f10 "${horizontal_ps}"
gmt psscale -R -J -C"${value_cpt}" -Dx-6.0i/-0.75i+w7.45i/0.13i+h \
	-Bxa1f0.5+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${horizontal_ps}"

# Vertical figure along y = 50.
gmt grdimage "${work_dir}/reference_vertical.nc" -P -R${region} \
	-J${vertical_projection} -C"${value_cpt}" -Bxa20f10+l"X (km)" \
	-Bya20f10+l"Z (km)" -BWSen+t"(a) Reference" \
	-X0.55i -Y4.05i -K > "${vertical_ps}"
gmt psxy "${work_dir}/gap_circle.txt" -R -J \
	-W1.5p,royalblue,- -O -K >> "${vertical_ps}"
plot_vertical "${work_dir}/gapped_vertical.nc" "(b) Gapped" \
	2.0i 0i -Bya20f10 "${vertical_ps}"
plot_vertical "${work_dir}/akima_vertical.nc" "(c) ${titles[0]}" \
	2.0i 0i -Bya20f10 "${vertical_ps}"
plot_vertical "${work_dir}/cubic_vertical.nc" "(d) ${titles[1]}" \
	2.0i 0i -Bya20f10 "${vertical_ps}"
plot_vertical "${work_dir}/step_vertical.nc" "(e) ${titles[2]}" \
	-6.0i -2.35i -Bya20f10+l"Z (km)" "${vertical_ps}"
plot_vertical "${work_dir}/linear_vertical.nc" "(f) ${titles[3]}" \
	2.0i 0i -Bya20f10 "${vertical_ps}"
plot_vertical "${work_dir}/nearest_vertical.nc" "(g) ${titles[4]}" \
	2.0i 0i -Bya20f10 "${vertical_ps}"
plot_vertical "${work_dir}/smoothing_vertical.nc" "(h) ${titles[5]}" \
	2.0i 0i -Bya20f10 "${vertical_ps}"
gmt psscale -R -J -C"${value_cpt}" -Dx-6.0i/-0.75i+w7.45i/0.13i+h \
	-Bxa1f0.5+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${vertical_ps}"

gmt psconvert "${horizontal_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex07_gap_methods_horizontal"
gmt psconvert "${horizontal_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex07_gap_methods_horizontal"
gmt psconvert "${vertical_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex07_gap_methods_vertical"
gmt psconvert "${vertical_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex07_gap_methods_vertical"
