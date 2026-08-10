#!/usr/bin/env bash
#
# Map differently named 3-D NetCDF variables into one multiparameter output.

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
ncdump_executable=${NCDUMP:-$(command -v ncdump || true)}
if [[ -z "${ncdump_executable}" ]]; then
	echo "ncdump was not found; set NCDUMP=/path/to/ncdump" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex05-netcdf.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=0/100/0/100
increment=2
zrange=0/100/2
horizontal_projection=X1.45i/1.45i
vertical_projection=X1.45i/-1.45i
primary_cdl="${work_dir}/model1.cdl"
secondary_cdl="${work_dir}/model2.cdl"
primary_nc="${work_dir}/model1.nc"
secondary_nc="${work_dir}/model2.nc"
support="${work_dir}/isotoxal_star.txt"
mergefile="${work_dir}/models.merge3d"
merged_nc="${work_dir}/merged.nc"
weight_only_nc="${work_dir}/weight_only.nc"
ps_file="${work_dir}/ex05_multivariable_netcdf.ps"
vp_cpt="${work_dir}/vp.cpt"
vs_cpt="${work_dir}/vs.cpt"
rho_cpt="${work_dir}/rho.cpt"
weight_cpt="${work_dir}/weight.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=20.2p

# Model 1 uses vp, vs, and den within the inner cube.
awk 'BEGIN {
	xmin = 20; xmax = 80; ymin = 20; ymax = 80
	zmin = 20; zmax = 80; inc = 2
	nx = (xmax - xmin) / inc + 1
	ny = (ymax - ymin) / inc + 1
	nz = (zmax - zmin) / inc + 1
	n = nx * ny * nz
	print "netcdf model1 {"
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
	print "\t\tvp:long_name = \"model 1 compressional speed\" ;"
	print "\t\tvp:units = \"km/s\" ;"
	print "\tfloat vs(z, y, x) ;"
	print "\t\tvs:long_name = \"model 1 shear speed\" ;"
	print "\t\tvs:units = \"km/s\" ;"
	print "\tfloat den(z, y, x) ;"
	print "\t\tden:long_name = \"model 1 density\" ;"
	print "\t\tden:units = \"g/cm3\" ;"
	print "\n// global attributes:"
	print "\t\t:Conventions = \"CF-1.8\" ;"
	print "data:"
	printf "\tz = "
	for (k = 0; k < nz; k++) printf "%g%s", zmin + k * inc, (k == nz - 1 ? " ;\n" : ", ")
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%g%s", ymin + j * inc, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%g%s", xmin + i * inc, (i == nx - 1 ? " ;\n" : ", ")
	printf "\tvp ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * inc
		v = 6.8 + 0.006 * x + 0.003 * y + 0.010 * z + 0.6 * exp(-((x - 50)^2 + (y - 50)^2 + (z - 50)^2) / 700)
		printf "%s%.7g%s", (q % 8 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	printf "\tvs ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * inc
		v = 3.8 + 0.003 * x + 0.002 * y + 0.006 * z + 0.35 * exp(-((x - 52)^2 + (y - 48)^2 + (z - 55)^2) / 800)
		printf "%s%.7g%s", (q % 8 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	printf "\tden ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * inc
		v = 2.65 + 0.0008 * x + 0.0005 * y + 0.0012 * z + 0.10 * exp(-((x - 48)^2 + (y - 52)^2 + (z - 50)^2) / 900)
		printf "%s%.7g%s", (q % 8 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	print "}"
}' > "${primary_cdl}"

# Model 2 uses the equivalent names p, s, and d over the full cube.
awk 'BEGIN {
	xmin = 0; xmax = 100; ymin = 0; ymax = 100
	zmin = 0; zmax = 100; inc = 2
	nx = (xmax - xmin) / inc + 1
	ny = (ymax - ymin) / inc + 1
	nz = (zmax - zmin) / inc + 1
	n = nx * ny * nz
	print "netcdf model2 {"
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
	print "\t\tp:long_name = \"model 2 compressional speed\" ;"
	print "\t\tp:units = \"km/s\" ;"
	print "\tfloat s(z, y, x) ;"
	print "\t\ts:long_name = \"model 2 shear speed\" ;"
	print "\t\ts:units = \"km/s\" ;"
	print "\tfloat d(z, y, x) ;"
	print "\t\td:long_name = \"model 2 density\" ;"
	print "\t\td:units = \"g/cm3\" ;"
	print "\n// global attributes:"
	print "\t\t:Conventions = \"CF-1.8\" ;"
	print "data:"
	printf "\tz = "
	for (k = 0; k < nz; k++) printf "%g%s", zmin + k * inc, (k == nz - 1 ? " ;\n" : ", ")
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%g%s", ymin + j * inc, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%g%s", xmin + i * inc, (i == nx - 1 ? " ;\n" : ", ")
	printf "\tp ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * inc
		v = 5.5 + 0.003 * x + 0.0015 * y + 0.006 * z + 0.15 * sin((x + y + z) / 18)
		printf "%s%.7g%s", (q % 8 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	printf "\ts ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * inc
		v = 3.0 + 0.0015 * x + 0.001 * y + 0.0035 * z + 0.08 * cos((x + z) / 16)
		printf "%s%.7g%s", (q % 8 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	printf "\td ="
	q = 0
	for (k = 0; k < nz; k++) for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc; z = zmin + k * inc
		v = 2.45 + 0.0005 * x + 0.0004 * y + 0.0008 * z + 0.025 * sin((y + z) / 14)
		printf "%s%.7g%s", (q % 8 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
	}
	print "}"
}' > "${secondary_cdl}"

"${ncgen_executable}" -4 -o "${primary_nc}" "${primary_cdl}"
"${ncgen_executable}" -4 -o "${secondary_nc}" "${secondary_cdl}"

# Four equal outer points alternate with four equal inner vertices.
cat > "${support}" <<- EOF
	50 20
	41.5 41.5
	20 50
	41.5 58.5
	50 80
	58.5 58.5
	80 50
	58.5 41.5
	50 20
	EOF

# Source variables map positionally to the final names supplied by -F.
cat > "${mergefile}" <<- EOF
	${primary_nc}?vp,vs,den ${secondary_nc}?p,s,d ${support} - cosine/cosine/cosine 0.3
	${secondary_nc}?p,s,d - - - - -
	EOF
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvp,vs,rho -W -G"${merged_nc}"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-Fvp,vs,rho -W+o -G"${weight_only_nc}"

# Confirm output names, field units, weight metadata, and weight-only behavior.
"${ncdump_executable}" -h "${merged_nc}" > "${work_dir}/merged.header"
for variable in vp vs rho weight; do
	grep -Eq "(float|double) ${variable}\\(" "${work_dir}/merged.header"
done
grep -q 'vp:units = "km/s"' "${work_dir}/merged.header"
grep -q 'vs:units = "km/s"' "${work_dir}/merged.header"
grep -q 'rho:units = "g/cm3"' "${work_dir}/merged.header"
grep -q 'weight:long_name = "merging weight"' "${work_dir}/merged.header"
grep -q 'weight:units = "1"' "${work_dir}/merged.header"
"${ncdump_executable}" -h "${weight_only_nc}" > "${work_dir}/weight_only.header"
grep -Eq '(float|double) weight\(' "${work_dir}/weight_only.header"
if grep -Eq '(float|double) (vp|vs|rho)\(' "${work_dir}/weight_only.header"; then
	echo "-W+o unexpectedly wrote model variables" >&2
	exit 1
fi

# Extract corresponding horizontal slices at z = 50 and vertical sections at y = 50.
for specification in \
	"vp vp p" \
	"vs vs s" \
	"rho den d"
do
	read -r output_field primary_field secondary_field <<< "${specification}"
	gmt grdconvert "${merged_nc}?${output_field}[25]" \
		"${work_dir}/${output_field}_horizontal.nc"
	gmt grdcut "${merged_nc}?${output_field}" -Ey50 \
		-G"${work_dir}/${output_field}_vertical.nc"
	gmt grdconvert "${primary_nc}?${primary_field}[15]" \
		"${work_dir}/${output_field}_primary_horizontal.nc"
	gmt grdconvert "${secondary_nc}?${secondary_field}[25]" \
		"${work_dir}/${output_field}_secondary_horizontal.nc"
	gmt grdcut "${primary_nc}?${primary_field}" -Ey50 \
		-G"${work_dir}/${output_field}_primary_vertical.nc"
	gmt grdcut "${secondary_nc}?${secondary_field}" -Ey50 \
		-G"${work_dir}/${output_field}_secondary_vertical.nc"
done
gmt grdconvert "${merged_nc}?weight[25]" "${work_dir}/weight_horizontal.nc"
gmt grdcut "${merged_nc}?weight" -Ey50 -G"${work_dir}/weight_vertical.nc"
gmt grdconvert "${weight_only_nc}?weight[25]" \
	"${work_dir}/weight_only_horizontal.nc"
gmt grdcut "${weight_only_nc}?weight" -Ey50 \
	-G"${work_dir}/weight_only_vertical.nc"
for view in horizontal vertical; do
	gmt grdmath "${work_dir}/weight_${view}.nc" \
		"${work_dir}/weight_only_${view}.nc" SUB = \
		"${work_dir}/weight_difference_${view}.nc"
	gmt grdinfo "${work_dir}/weight_difference_${view}.nc" -C | \
		awk '$6 != 0 || $7 != 0 {exit 1}'
done

# Verify every field against the same merging weight in both plotted views.
for output_field in vp vs rho; do
	for view in horizontal vertical; do
		gmt grdcut "${work_dir}/${output_field}_secondary_${view}.nc" \
			-R20/80/20/80 \
			-G"${work_dir}/secondary_${output_field}_${view}_support.nc"
		gmt grdcut "${work_dir}/weight_${view}.nc" -R20/80/20/80 \
			-G"${work_dir}/weight_${output_field}_${view}_support.nc"
		gmt grdmath "${work_dir}/weight_${output_field}_${view}_support.nc" \
			"${work_dir}/${output_field}_primary_${view}.nc" MUL \
			1 "${work_dir}/weight_${output_field}_${view}_support.nc" SUB \
			"${work_dir}/secondary_${output_field}_${view}_support.nc" MUL ADD = \
			"${work_dir}/${output_field}_expected_${view}.nc"
		gmt grdcut "${work_dir}/${output_field}_${view}.nc" -R20/80/20/80 \
			-G"${work_dir}/${output_field}_${view}_support.nc"
		gmt grdmath "${work_dir}/${output_field}_${view}_support.nc" \
			"${work_dir}/${output_field}_expected_${view}.nc" SUB = \
			"${work_dir}/${output_field}_difference_${view}.nc"
		gmt grdinfo "${work_dir}/${output_field}_difference_${view}.nc" -C | \
			awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
	done
done
for view in horizontal vertical; do
	gmt grdinfo "${work_dir}/weight_${view}.nc" -C | \
		awk '$6 < 0 || $7 > 1 {exit 1}'
done

cat > "${work_dir}/vertical_support.txt" <<- EOF
	20 20
	80 20
	80 80
	20 80
	20 20
	EOF

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T5.5/8.4/0.1 -Z > "${vp_cpt}"
gmt makecpt -Cturbo -T3.0/4.8/0.1 -Z > "${vs_cpt}"
gmt makecpt -Cturbo -T2.45/2.95/0.05 -Z > "${rho_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

plot_horizontal() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} -C"${cpt}" \
		-Bxa20f10+l"X (km)" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	gmt psxy "${support}" -R -J \
		-W1.5p,orangered,- -O -K >> "${ps_file}"
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
}

plot_horizontal_hotpink() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} -C"${cpt}" \
		-Bxa20f10+l"X (km)" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	gmt psxy "${support}" -R -J \
		-W1.5p,orangered,- -O -K >> "${ps_file}"
	printf "0 50\n100 50\n" | \
		gmt psxy -R -J -W1.5p,hotpink,-- -O -K >> "${ps_file}"
}

plot_vertical() {
	local grid=$1 cpt=$2 title=$3 xshift=$4 yshift=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${vertical_projection} -C"${cpt}" \
		-Bxa20f10+l"X (km)" "${yaxis}" "-BWSen+t${title}" \
		-X${xshift} -Y${yshift} -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/vertical_support.txt" -R -J \
		-W1.5p,orangered,- -O -K >> "${ps_file}"
}

# Top row: mapped output variables and their shared weight at z = 50.
gmt grdimage "${work_dir}/vp_horizontal.nc" -P -R${region} \
	-J${horizontal_projection} -C"${vp_cpt}" -Bxa20f10+l"X (km)" \
	-Bya20f10+l"Y (km)" -BWSen+t"(a) Vp: z = 50 km" \
	-X0.55i -Y4.05i -K > "${ps_file}"
gmt psxy "${support}" -R -J \
	-W1.5p,orangered,- -O -K >> "${ps_file}"
printf "0 50\n100 50\n" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
plot_horizontal "${work_dir}/vs_horizontal.nc" "${vs_cpt}" \
	"(b) Vs: z = 50 km" 2.0i 0i -Bya20f10
plot_horizontal "${work_dir}/rho_horizontal.nc" "${rho_cpt}" \
	"(c) Density: z = 50 km" 2.0i 0i -Bya20f10
plot_horizontal_hotpink "${work_dir}/weight_horizontal.nc" "${weight_cpt}" \
	"(d) Weight: z = 50 km" 2.0i 0i -Bya20f10

# Bottom row: the same output variables along y = 50.
plot_vertical "${work_dir}/vp_vertical.nc" "${vp_cpt}" \
	"(e) Vp: y = 50 km" -6.0i -2.35i -Bya20f10+l"Z (km)"
plot_vertical "${work_dir}/vs_vertical.nc" "${vs_cpt}" \
	"(f) Vs: y = 50 km" 2.0i 0i -Bya20f10
plot_vertical "${work_dir}/rho_vertical.nc" "${rho_cpt}" \
	"(g) Density: y = 50 km" 2.0i 0i -Bya20f10
plot_vertical "${work_dir}/weight_vertical.nc" "${weight_cpt}" \
	"(h) Weight: y = 50 km" 2.0i 0i -Bya20f10

gmt psscale -R -J -C"${vp_cpt}" -Dx-6.0i/-0.75i+w1.45i/0.12i+h \
	-Bxa0.5f0.1+l"Vp (km/s)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"
gmt psscale -R -J -C"${vs_cpt}" -Dx-4.0i/-0.75i+w1.45i/0.12i+h \
	-Bxa0.5f0.1+l"Vs (km/s)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"
gmt psscale -R -J -C"${rho_cpt}" -Dx-2.0i/-0.75i+w1.45i/0.12i+h \
	-Bxa0.1f0.05+l"Density (g/cm3)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"
gmt psscale -R -J -C"${weight_cpt}" -Dx0i/-0.75i+w1.45i/0.12i+h \
	-Bxa0.2f0.1+l"Merging weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A+m0.1i -Tf \
	-F"${script_dir}/ex05_multivariable_netcdf"
gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex05_multivariable_netcdf"
