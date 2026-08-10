#!/usr/bin/env bash
#
# Extend the merge2d missing-value example through a third dimension.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex06-missing.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=0/100/0/100
increment=1
zrange=0/100/1
horizontal_projection=X1.2i/1.2i
vertical_projection=X1.2i/-1.2i
primary_cdl="${work_dir}/primary.cdl"
secondary_cdl="${work_dir}/secondary.cdl"
primary_nc="${work_dir}/primary.nc"
secondary_nc="${work_dir}/secondary.nc"
mergefile="${work_dir}/missing.merge3d"
merged_nc="${work_dir}/merged.nc"
filled_nc="${work_dir}/filled.nc"
ps_file="${work_dir}/ex06_missing_values.ps"
value_cpt="${work_dir}/values.cpt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=14p

# The primary occupies 15/85 in x, y, and z and stores a missing block as its
# declared NetCDF fill value. At z = 50, this is the vertical band from ex07.
awk 'BEGIN {
	xmin = 15; xmax = 85; ymin = 15; ymax = 85
	zmin = 15; zmax = 85; inc = 1; zinc = 2
	nx = (xmax - xmin) / inc + 1
	ny = (ymax - ymin) / inc + 1
	nz = (zmax - zmin) / zinc + 1
	n = nx * ny * nz
	print "netcdf primary {"
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
	print "\tfloat vp(z, y, x) ;"
	print "\t\tvp:_FillValue = -99999.f ;"
	print "\t\tvp:long_name = \"primary model\" ;"
	print "data:"
	printf "\tz = "
	for (k = 0; k < nz; k++) printf "%g%s", zmin + k * zinc, (k == nz - 1 ? " ;\n" : ", ")
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%g%s", ymin + j * inc, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%g%s", xmin + i * inc, (i == nx - 1 ? " ;\n" : ", ")
	printf "\tvp ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * zinc
		missing = (x >= 42 && x <= 58 && y >= 25 && y <= 75 && z >= 15 && z <= 75)
		v = missing ? -99999 : 8
		printf "%s%.7g%s", (q % 10 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	print "}"
}' > "${primary_cdl}"

# The secondary covers the output cube and stores a perpendicular missing
# block as undeclared -99999 values, identified later with GMT -di.
awk 'BEGIN {
	xmin = 0; xmax = 100; ymin = 0; ymax = 100
	zmin = 0; zmax = 100; inc = 1; zinc = 2
	nx = (xmax - xmin) / inc + 1
	ny = (ymax - ymin) / inc + 1
	nz = (zmax - zmin) / zinc + 1
	n = nx * ny * nz
	print "netcdf secondary {"
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
	print "\tfloat p(z, y, x) ;"
	print "\t\tp:long_name = \"secondary model\" ;"
	print "data:"
	printf "\tz = "
	for (k = 0; k < nz; k++) printf "%g%s", zmin + k * zinc, (k == nz - 1 ? " ;\n" : ", ")
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%g%s", ymin + j * inc, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%g%s", xmin + i * inc, (i == nx - 1 ? " ;\n" : ", ")
	printf "\tp ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * zinc
		missing = (x >= 0 && x <= 75 && y >= 42 && y <= 58 && z >= 42 && z <= 58)
		v = missing ? -99999 : 2
		printf "%s%.7g%s", (q % 10 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	print "}"
}' > "${secondary_cdl}"

"${ncgen_executable}" -4 -o "${primary_nc}" "${primary_cdl}"
"${ncgen_executable}" -4 -o "${secondary_nc}" "${secondary_cdl}"

cat > "${mergefile}" <<- EOF
	${primary_nc}?vp ${secondary_nc}?p - - cosine/cosine/cosine 0.25
	${secondary_nc}?p - - - - -
	EOF
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvp -di-99999 -W -nl -G"${merged_nc}"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvp -di-99999 -Hl -Sl+g -W -nl -G"${filled_nc}"

# Extract input and output views at z = 50 and y = 50.
gmt grdinterpolate "${primary_nc}?vp" -T50 \
	-G"${work_dir}/primary_horizontal.nc"
gmt grdconvert "${secondary_nc}?p[25]" "${work_dir}/secondary_raw_horizontal.nc"
gmt grdmath "${work_dir}/secondary_raw_horizontal.nc" -99999 NAN = \
	"${work_dir}/secondary_horizontal.nc"
gmt grdcut "${primary_nc}?vp" -Ey50 -G"${work_dir}/primary_vertical.nc"
gmt grdcut "${secondary_nc}?p" -Ey50 \
	-G"${work_dir}/secondary_raw_vertical.nc"
gmt grdmath "${work_dir}/secondary_raw_vertical.nc" -99999 NAN = \
	"${work_dir}/secondary_vertical.nc"
for name in merged filled; do
	gmt grdconvert "${work_dir}/${name}.nc?vp[50]" \
		"${work_dir}/${name}_horizontal.nc"
	gmt grdconvert "${work_dir}/${name}.nc?weight[50]" \
		"${work_dir}/${name}_weight_horizontal.nc"
	gmt grdcut "${work_dir}/${name}.nc?vp" -Ey50 \
		-G"${work_dir}/${name}_vertical.nc"
	gmt grdcut "${work_dir}/${name}.nc?weight" -Ey50 \
		-G"${work_dir}/${name}_weight_vertical.nc"
done

# Check one-source fallback and the shared missing volume in both views.
printf "50 30\n30 50\n50 50\n" | \
	gmt grdtrack -G"${work_dir}/merged_horizontal.nc" > "${work_dir}/horizontal_samples.txt"
awk 'NR == 1 && ($3 - 2)^2 > 1e-10 {exit 1}
	 NR == 2 && ($3 - 8)^2 > 1e-10 {exit 1}
	 NR == 3 && tolower($3) != "nan" {exit 1}' \
	"${work_dir}/horizontal_samples.txt"
printf "50 30\n30 50\n50 50\n" | \
	gmt grdtrack -G"${work_dir}/merged_vertical.nc" > "${work_dir}/vertical_samples.txt"
awk 'NR == 1 && ($3 - 2)^2 > 1e-10 {exit 1}
	 NR == 2 && ($3 - 8)^2 > 1e-10 {exit 1}
	 NR == 3 && tolower($3) != "nan" {exit 1}' \
	"${work_dir}/vertical_samples.txt"

# After -H and -S+g fill the orthogonal gaps, constants obey z = 2 + 6w.
for view in horizontal vertical; do
	gmt grdmath "${work_dir}/filled_weight_${view}.nc" 6 MUL 2 ADD = \
		"${work_dir}/expected_${view}.nc"
	gmt grdmath "${work_dir}/filled_${view}.nc" \
		"${work_dir}/expected_${view}.nc" SUB = \
		"${work_dir}/difference_${view}.nc"
	gmt grdinfo "${work_dir}/difference_${view}.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
done
gmt grdinfo "${work_dir}/filled_horizontal.nc" -C | \
	awk '$6 != $6 || $7 != $7 {exit 1}'

# Horizontal and vertical outlines of the primary support and both gaps.
cat > "${work_dir}/support_horizontal.txt" <<- EOF
	15 15
	85 15
	85 85
	15 85
	15 15
	EOF
cat > "${work_dir}/primary_gap_horizontal.txt" <<- EOF
	42 25
	58 25
	58 75
	42 75
	42 25
	EOF
cat > "${work_dir}/secondary_gap_horizontal.txt" <<- EOF
	0 42
	75 42
	75 58
	0 58
	0 42
	EOF
cat > "${work_dir}/support_vertical.txt" <<- EOF
	15 15
	85 15
	85 85
	15 85
	15 15
	EOF
cat > "${work_dir}/primary_gap_vertical.txt" <<- EOF
	42 15
	58 15
	58 75
	42 75
	42 15
	EOF
cat > "${work_dir}/secondary_gap_vertical.txt" <<- EOF
	0 42
	75 42
	75 58
	0 58
	0 42
	EOF

gmt set FONT_ANNOT_PRIMARY 9p FONT_LABEL 10p FONT_TITLE 10p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T2/8/1 -Z > "${value_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

draw_horizontal_overlays() {
	case $1 in
		primary)
			gmt psxy "${work_dir}/support_horizontal.txt" -R -J \
				-W1.3p,black,- -O -K >> "${ps_file}"
			gmt psxy "${work_dir}/primary_gap_horizontal.txt" -R -J \
				-W1.3p,royalblue,- -O -K >> "${ps_file}"
			;;
		secondary)
			gmt psxy "${work_dir}/secondary_gap_horizontal.txt" -R -J \
				-W1.3p,orangered,- -O -K >> "${ps_file}"
			;;
		weight)
			gmt psxy "${work_dir}/support_horizontal.txt" -R -J \
				-W1.3p,orangered,- -O -K >> "${ps_file}"
			;;
		both)
			gmt psxy "${work_dir}/primary_gap_horizontal.txt" -R -J \
				-W1.3p,royalblue,- -O -K >> "${ps_file}"
			gmt psxy "${work_dir}/secondary_gap_horizontal.txt" -R -J \
				-W1.3p,orangered,- -O -K >> "${ps_file}"
			;;
	esac
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.3p,black,-- -O -K >> "${ps_file}"
}

draw_vertical_overlays() {
	case $1 in
		primary)
			gmt psxy "${work_dir}/support_vertical.txt" -R -J \
				-W1.3p,black,- -O -K >> "${ps_file}"
			gmt psxy "${work_dir}/primary_gap_vertical.txt" -R -J \
				-W1.3p,royalblue,- -O -K >> "${ps_file}"
			;;
		secondary)
			gmt psxy "${work_dir}/secondary_gap_vertical.txt" -R -J \
				-W1.3p,orangered,- -O -K >> "${ps_file}"
			;;
		weight)
			gmt psxy "${work_dir}/support_vertical.txt" -R -J \
				-W1.3p,orangered,- -O -K >> "${ps_file}"
			;;
		both)
			gmt psxy "${work_dir}/primary_gap_vertical.txt" -R -J \
				-W1.3p,royalblue,- -O -K >> "${ps_file}"
			gmt psxy "${work_dir}/secondary_gap_vertical.txt" -R -J \
				-W1.3p,orangered,- -O -K >> "${ps_file}"
			;;
	esac
}

plot_horizontal() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6 overlays=$7
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} -C"${cpt}" \
		-Bxa20f10+l"X (km)" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	draw_horizontal_overlays "${overlays}"
}

plot_vertical() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6 overlays=$7
	gmt grdimage "${grid}" -R${region} -J${vertical_projection} -C"${cpt}" \
		-Bxa20f10+l"X (km)" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	draw_vertical_overlays "${overlays}"
}

# Top row: horizontal slices at z = 50.
gmt grdimage "${work_dir}/primary_horizontal.nc" -P -R${region} \
	-J${horizontal_projection} -C"${value_cpt}" -Bxa20f10+l"X (km)" \
	-Bya20f10+l"Y (km)" -BWSen+t"(a) Primary: z = 50" \
	-X0.4i -Y3.7i -K > "${ps_file}"
draw_horizontal_overlays primary
plot_horizontal "${work_dir}/secondary_horizontal.nc" "${value_cpt}" \
	"(b) Secondary: z = 50" 1.65i 0i -Bya20f10 secondary
plot_horizontal "${work_dir}/merged_weight_horizontal.nc" "${weight_cpt}" \
	"(c) Weight: z = 50" 1.65i 0i -Bya20f10 weight
plot_horizontal "${work_dir}/merged_horizontal.nc" "${value_cpt}" \
	"(d) Merged: z = 50" 1.65i 0i -Bya20f10 both
plot_horizontal "${work_dir}/filled_horizontal.nc" "${value_cpt}" \
	"(e) Gaps filled: z = 50" 1.65i 0i -Bya20f10 both

# Bottom row: vertical sections along y = 50.
plot_vertical "${work_dir}/primary_vertical.nc" "${value_cpt}" \
	"(f) Primary: y = 50" -6.6i -2.05i -Bya20f10+l"Z (km)" primary
plot_vertical "${work_dir}/secondary_vertical.nc" "${value_cpt}" \
	"(g) Secondary: y = 50" 1.65i 0i -Bya20f10 secondary
plot_vertical "${work_dir}/merged_weight_vertical.nc" "${weight_cpt}" \
	"(h) Weight: y = 50" 1.65i 0i -Bya20f10 weight
plot_vertical "${work_dir}/merged_vertical.nc" "${value_cpt}" \
	"(i) Merged: y = 50" 1.65i 0i -Bya20f10 both
plot_vertical "${work_dir}/filled_vertical.nc" "${value_cpt}" \
	"(j) Gaps filled: y = 50" 1.65i 0i -Bya20f10 both

gmt psscale -R -J -C"${weight_cpt}" \
	-Dx-6.6i/-0.7i+w3.0i/0.12i+h \
	-Bxa0.2f0.1+l"Merging weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" \
	-Dx-3.2i/-0.7i+w3.0i/0.12i+h \
	-Bxa1f0.5+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A+m0.1i -Tf \
	-F"${script_dir}/ex06_missing_values"
gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex06_missing_values"
