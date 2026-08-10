#!/usr/bin/env bash
#
# Merge layers selected directly from a 3-D NetCDF variable.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex06-layers.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
projection=X3.15i/3.15i
model_cdl="${work_dir}/model3d.cdl"
model_nc="${work_dir}/model3d.nc"
support="${work_dir}/diamond.txt"
mergefile="${work_dir}/layers.merge2d"
index_slice="${work_dir}/index_slice.nc"
level_slice="${work_dir}/level_slice.nc"
merged="${work_dir}/merged.nc"
ps_file="${work_dir}/ex06_layer_selection.ps"
value_cpt="${work_dir}/values.cpt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=15.37p

# Build a four-layer model with increasing horizontal and vertical coordinates.
awk 'BEGIN {
	pi = atan2(0, -1)
	nz = 4; ny = 101; nx = 101
	print "netcdf model3d {"
	print "dimensions:"
	printf "\tdepth = %d ;\n\ty = %d ;\n\tx = %d ;\n", nz, ny, nx
	print "variables:"
	print "\tdouble depth(depth) ;"
	print "\t\tdepth:axis = \"Z\" ;"
	print "\t\tdepth:units = \"km\" ;"
	print "\t\tdepth:positive = \"down\" ;"
	print "\tdouble y(y) ;"
	print "\t\ty:axis = \"Y\" ;"
	print "\t\ty:actual_range = 0., 100. ;"
	print "\tdouble x(x) ;"
	print "\t\tx:axis = \"X\" ;"
	print "\t\tx:actual_range = 0., 100. ;"
	print "\tfloat vp(depth, y, x) ;"
	print "\t\tvp:long_name = \"compressional speed\" ;"
	print "\t\tvp:units = \"km/s\" ;"
	print "\n// global attributes:"
	print "\t\t:Conventions = \"COARDS\" ;"
	print "\t\t:node_offset = 0 ;"
	print "data:"
	print "\tdepth = 0, 10, 20, 30 ;"
	printf "\ty = "
	for (j = 0; j < ny; j++) printf "%d%s", j, (j == ny - 1 ? " ;\n" : ", ")
	printf "\tx = "
	for (i = 0; i < nx; i++) printf "%d%s", i, (i == nx - 1 ? " ;\n" : ", ")
	printf "\tvp ="
	n = nz * ny * nx
	q = 0
	for (k = 0; k < nz; k++) {
		z = 10 * k
		base = 5.2 + 0.04 * z
		amplitude = 0.7 * cos(z * pi / 30)
		for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) {
			gaussian = exp(-((i - 50)^2 + (j - 50)^2) / 700)
			v = base + amplitude * gaussian + 0.2 * sin((i + z) / 12) * cos(j / 15)
			printf "%s%.7g%s", (q % 8 == 0 ? "\n\t\t" : " "), v, (++q == n ? " ;\n" : ",")
		}
	}
	print "}"
}' > "${model_cdl}"
"${ncgen_executable}" -o "${model_nc}" "${model_cdl}"

# A strictly xy-monotone diamond limits where the shallower layer is primary.
cat > "${support}" <<- EOF
	50 15
	15 50
	50 85
	85 50
	50 15
	EOF

# Extract the known 10 and 30 km layers for plotting and validation.
gmt grdconvert "${model_nc}?vp[1]" "${index_slice}"
gmt grdconvert "${model_nc}?vp[3]" "${level_slice}"

cat > "${mergefile}" <<- EOF
	${model_nc}?vp[1] ${model_nc}?vp(28) ${support} cosine/cosine 0.3
	${model_nc}?vp(28) - - - -
	EOF
gmt merge2d "${mergefile}" -R${region} -I${increment} \
	-Fvp -W -G"${merged}"

# Verify both selected layers and the weighted merge.
gmt grdmath -R${region} -I${increment} \
	5.6 X 50 SUB 2 POW Y 50 SUB 2 POW ADD 700 DIV NEG EXP 0.35 MUL ADD \
	X 10 ADD 12 DIV SIN Y 15 DIV COS MUL 0.2 MUL ADD = \
	"${work_dir}/expected_index.nc"
gmt grdmath -R${region} -I${increment} \
	6.4 X 50 SUB 2 POW Y 50 SUB 2 POW ADD 700 DIV NEG EXP -0.7 MUL ADD \
	X 30 ADD 12 DIV SIN Y 15 DIV COS MUL 0.2 MUL ADD = \
	"${work_dir}/expected_level.nc"
for name in index level; do
	gmt grdmath "${work_dir}/${name}_slice.nc?vp" \
		"${work_dir}/expected_${name}.nc" SUB = \
		"${work_dir}/${name}_error.nc"
	gmt grdinfo "${work_dir}/${name}_error.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
done
gmt grdmath "${merged}?weight" "${index_slice}?vp" MUL \
	1 "${merged}?weight" SUB "${level_slice}?vp" MUL ADD = \
	"${work_dir}/expected_merge.nc"
gmt grdmath "${merged}?vp" "${work_dir}/expected_merge.nc" SUB = \
	"${work_dir}/merge_error.nc"
gmt grdinfo "${work_dir}/merge_error.nc" -C | \
	awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
gmt grdinfo "${merged}?weight" -C | \
	awk '$6 < 0 || $7 > 1 {exit 1}'

gmt makecpt -Cturbo -T5.2/6.8/0.1 -Z > "${value_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

# Panel (a): select the second layer by its zero-based index.
gmt grdimage "${index_slice}?vp" -P -R${region} -J${projection} \
	-C"${value_cpt}" -Bxa20f10 -Bya20f10+l"Y" \
	-BWSen+t"(a) vp[1]: 10 km" -X0.8i -Y5.25i -K > "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,black,- -O -K >> "${ps_file}"

# Panel (b): 28 km resolves to the nearest coordinate layer at 30 km.
gmt grdimage "${level_slice}?vp" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(b) vp(28): 30 km" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,black,- -O -K >> "${ps_file}"

# Panel (c): symmetric cosine taper within the diamond support.
gmt grdimage "${merged}?weight" -R -J -C"${weight_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(c) Merging weight" \
	-X-3.75i -Y-3.85i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${weight_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa0.2f0.1+l"Weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (d): merge the 10 km layer into the selected 30 km layer.
gmt grdimage "${merged}?vp" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(d) Merged slices" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -W1.5p,black,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa0.4f0.2+l"vp (km/s)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex06_layer_selection"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex06_layer_selection"
