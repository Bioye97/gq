#!/usr/bin/env bash
#
# Map differently named 2-D NetCDF variables into one multiparameter output.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex05-netcdf.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
projection=X3.15i/3.15i
primary_cdl="${work_dir}/model1.cdl"
secondary_cdl="${work_dir}/model2.cdl"
primary_nc="${work_dir}/model1.nc"
secondary_nc="${work_dir}/model2.nc"
support="${work_dir}/isotoxal_star.txt"
mergefile="${work_dir}/models.merge2d"
merged_nc="${work_dir}/merged.nc"
weight_only_nc="${work_dir}/weight_only.nc"
ps_file="${work_dir}/ex05_multivariable_netcdf.ps"
vp_cpt="${work_dir}/vp.cpt"
vs_cpt="${work_dir}/vs.cpt"
rho_cpt="${work_dir}/rho.cpt"
weight_cpt="${work_dir}/weight.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=15.37p

# Model 1 uses vp, vs, and den on the inner domain.
awk 'BEGIN {
	xmin = 20; xmax = 80; ymin = 20; ymax = 80; inc = 1
	nx = (xmax - xmin) / inc + 1
	ny = (ymax - ymin) / inc + 1
	n = nx * ny
	print "netcdf model1 {"
	print "dimensions:"
	printf "\ty = %d ;\n\tx = %d ;\n", ny, nx
	print "variables:"
	print "\tdouble y(y) ;"
	printf "\t\ty:actual_range = %.1f, %.1f ;\n", ymin, ymax
	print "\tdouble x(x) ;"
	printf "\t\tx:actual_range = %.1f, %.1f ;\n", xmin, xmax
	print "\tfloat vp(y, x) ;"
	print "\t\tvp:long_name = \"model 1 compressional speed\" ;"
	print "\tfloat vs(y, x) ;"
	print "\t\tvs:long_name = \"model 1 shear speed\" ;"
	print "\tfloat den(y, x) ;"
	print "\t\tden:long_name = \"model 1 density\" ;"
	print "\n// global attributes:"
	print "\t\t:Conventions = \"COARDS\" ;"
	print "\t\t:node_offset = 0 ;"
	print "data:"
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%g%s", ymin + j * inc, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%g%s", xmin + i * inc, (i == nx - 1 ? " ;\n" : ", ")
	printf "\tvp ="
	k = 0
	for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc
		v = 7.0 + 0.8 * exp(-((x - 50)^2 + (y - 50)^2) / 500) + 0.15 * sin(y / 9)
		printf "%s%.7g%s", (k % 8 == 0 ? "\n\t\t" : " "), v, (++k == n ? " ;\n" : ",")
	}
	printf "\tvs ="
	k = 0
	for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc
		v = 4.0 + 0.5 * exp(-((x - 52)^2 + (y - 48)^2) / 600) + 0.1 * cos(x / 10)
		printf "%s%.7g%s", (k % 8 == 0 ? "\n\t\t" : " "), v, (++k == n ? " ;\n" : ",")
	}
	printf "\tden ="
	k = 0
	for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc
		v = 2.78 + 0.16 * exp(-((x - 48)^2 + (y - 52)^2) / 700) + 0.03 * x / 100
		printf "%s%.7g%s", (k % 8 == 0 ? "\n\t\t" : " "), v, (++k == n ? " ;\n" : ",")
	}
	print "}"
}' > "${primary_cdl}"

# Model 2 uses the equivalent names p, s, and d over the full domain.
awk 'BEGIN {
	xmin = 0; xmax = 100; ymin = 0; ymax = 100; inc = 1
	nx = (xmax - xmin) / inc + 1
	ny = (ymax - ymin) / inc + 1
	n = nx * ny
	print "netcdf model2 {"
	print "dimensions:"
	printf "\ty = %d ;\n\tx = %d ;\n", ny, nx
	print "variables:"
	print "\tdouble y(y) ;"
	printf "\t\ty:actual_range = %.1f, %.1f ;\n", ymin, ymax
	print "\tdouble x(x) ;"
	printf "\t\tx:actual_range = %.1f, %.1f ;\n", xmin, xmax
	print "\tfloat p(y, x) ;"
	print "\t\tp:long_name = \"model 2 compressional speed\" ;"
	print "\tfloat s(y, x) ;"
	print "\t\ts:long_name = \"model 2 shear speed\" ;"
	print "\tfloat d(y, x) ;"
	print "\t\td:long_name = \"model 2 density\" ;"
	print "\n// global attributes:"
	print "\t\t:Conventions = \"COARDS\" ;"
	print "\t\t:node_offset = 0 ;"
	print "data:"
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%g%s", ymin + j * inc, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%g%s", xmin + i * inc, (i == nx - 1 ? " ;\n" : ", ")
	printf "\tp ="
	k = 0
	for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc
		v = 5.5 + 0.004 * x + 0.002 * y + 0.12 * sin((x + y) / 18)
		printf "%s%.7g%s", (k % 8 == 0 ? "\n\t\t" : " "), v, (++k == n ? " ;\n" : ",")
	}
	printf "\ts ="
	k = 0
	for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc
		v = 3.05 + 0.0025 * y + 0.08 * cos(x / 16)
		printf "%s%.7g%s", (k % 8 == 0 ? "\n\t\t" : " "), v, (++k == n ? " ;\n" : ",")
	}
	printf "\td ="
	k = 0
	for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
		x = xmin + i * inc; y = ymin + j * inc
		v = 2.48 + 0.001 * x + 0.0007 * y + 0.025 * sin(y / 14)
		printf "%s%.7g%s", (k % 8 == 0 ? "\n\t\t" : " "), v, (++k == n ? " ;\n" : ",")
	}
	print "}"
}' > "${secondary_cdl}"

"${ncgen_executable}" -o "${primary_nc}" "${primary_cdl}"
"${ncgen_executable}" -o "${secondary_nc}" "${secondary_cdl}"

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
	${primary_nc}?vp,vs,den ${secondary_nc}?p,s,d ${support} cosine/cosine 0.3
	${secondary_nc}?p,s,d - - - -
	EOF
gmt merge2d "${mergefile}" -R${region} -I${increment} \
	-Fvp,vs,rho -W -G"${merged_nc}"
gmt merge2d "${mergefile}" -R${region} -I${increment} \
	-W+o -G"${weight_only_nc}"

# Confirm output variable names, weight metadata, and weight-only behavior.
"${ncdump_executable}" -h "${merged_nc}" > "${work_dir}/merged.header"
for variable in vp vs rho weight; do
	grep -Eq "(float|double) ${variable}\\(" "${work_dir}/merged.header"
done
grep -q 'weight:long_name = "merging weight"' "${work_dir}/merged.header"
grep -q 'weight:units = "1"' "${work_dir}/merged.header"
"${ncdump_executable}" -h "${weight_only_nc}" > "${work_dir}/weight_only.header"
grep -Eq '(float|double) weight\(' "${work_dir}/weight_only.header"
if grep -Eq '(float|double) (vp|vs|rho)\(' "${work_dir}/weight_only.header"; then
	echo "-W+o unexpectedly wrote model variables" >&2
	exit 1
fi
gmt grdmath "${merged_nc}?weight" "${weight_only_nc}?weight" SUB = \
	"${work_dir}/weight_difference.nc"
gmt grdinfo "${work_dir}/weight_difference.nc" -C | \
	awk '$6 != 0 || $7 != 0 {exit 1}'
gmt grdinfo "${merged_nc}?weight" -C | \
	awk '$6 < 0 || $7 > 1 {exit 1}'

gmt makecpt -Cturbo -T5.4/8/0.2 -Z > "${vp_cpt}"
gmt makecpt -Cturbo -T2.9/4.7/0.1 -Z > "${vs_cpt}"
gmt makecpt -Cturbo -T2.45/3.05/0.05 -Z > "${rho_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

# Panel (a): vp and p map to output variable vp.
gmt grdimage "${merged_nc}?vp" -P -R${region} -J${projection} -C"${vp_cpt}" \
	-Bxa20f10 -Bya20f10+l"Y" -BWSen+t"(a) vp <- vp, p" \
	-X0.8i -Y6.2i -K > "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,black,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${vp_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.72i \
	-Bxa0.5f0.1+l"vp" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (b): vs and s map to output variable vs.
gmt grdimage "${merged_nc}?vs" -R -J -C"${vs_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(b) vs <- vs, s" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,black,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${vs_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.72i \
	-Bxa0.5f0.1+l"vs" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (c): den and d map to output variable rho.
gmt grdimage "${merged_nc}?rho" -R -J -C"${rho_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(c) rho <- den, d" \
	-X-3.75i -Y-4.45i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,black,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${rho_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa0.1f0.05+l"rho" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (d): all output fields share one asymmetric merging weight.
gmt grdimage "${merged_nc}?weight" -R -J -C"${weight_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(d) Shared merging weight" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${weight_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa0.2f0.1+l"Weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex05_multivariable_netcdf"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex05_multivariable_netcdf"
