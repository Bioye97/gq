#!/usr/bin/env bash
#
# Convert a non-monotone polygon before blending two grids.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex03-polygon.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-85/-30/-60/15
increment=0.25
projection=X2.2i/3.0i
primary="${work_dir}/primary.nc"
secondary="${work_dir}/secondary.nc"
support="${script_dir}/south_america.txt"
converted="${script_dir}/south_america_monotone.txt"
mergefile="${work_dir}/polygon.merge2d"
merged="${work_dir}/merged.nc"
ps_file="${work_dir}/ex03_polygon_conversion.ps"
value_cpt="${work_dir}/values.cpt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=17.64p

# Generate constant full-domain input grids.
gmt grdmath -R${region} -I${increment} 8 = "${primary}"
gmt grdmath -R${region} -I${increment} 2 = "${secondary}"

# Convert the requested polygon to its strict xy-monotone envelope.
cat > "${mergefile}" <<- EOF
	${primary} ${secondary} ${support} cosine/cosine 0.49
	${secondary} - - - -
	EOF
gmt merge2d "${mergefile}" -R${region} -I${increment} -ME+w -W \
	-G"${merged}"
[[ -s "${converted}" ]]

# Verify the weighted combination at every output node.
gmt grdmath "${merged}?weight" "${primary}" MUL \
	1 "${merged}?weight" SUB "${secondary}" MUL ADD = \
	"${work_dir}/expected.nc"
gmt grdmath "${merged}?z" "${work_dir}/expected.nc" SUB = \
	"${work_dir}/difference.nc"
gmt grdinfo "${work_dir}/difference.nc" -C | \
	awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'

gmt makecpt -Cturbo -T2/8/1 -Z > "${value_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

# Panel (a): primary input grid.
gmt grdimage "${primary}" -P -R${region} -J${projection} -C"${value_cpt}" \
	-Bxa10f5 -Bya15f5+l"Latitude" -BWSen+t"(a) Primary" \
	-X0.7i -Y6.25i -K > "${ps_file}"
gmt psxy "${support}" -R -J -L -W1p,white,- -O -K >> "${ps_file}"

# Panel (b): secondary input grid.
gmt grdimage "${secondary}" -R -J -C"${value_cpt}" \
	-Bxa10f5 -Bya15f5 -BWSen+t"(b) Secondary" \
	-X2.75i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1p,white,- -O -K >> "${ps_file}"

# Panel (c): requested South America polygon.
gmt psbasemap -R -J -Bxa10f5 -Bya15f5 \
	-BWSen+t"(c) Input polygon/clip" -X2.75i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1p,black,- \
	-O -K >> "${ps_file}"

# Panel (d): strict envelope written by -ME+w.
gmt psbasemap -R -J -Bxa10f5+l"Longitude" -Bya15f5+l"Latitude" \
	-BWSen+t"(d) -ME envelope" -X-5.5i -Y-3.7i -O -K >> "${ps_file}"
gmt psxy "${converted}" -R -J -L -W1p,black -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (e): the taper follows the converted support.
gmt grdimage "${merged}?weight" -R -J -C"${weight_cpt}" \
	-Bxf5 -Bya15f5 -BWSen+t"(e) Merging weight" \
	-X2.75i -O -K >> "${ps_file}"
gmt psxy "${converted}" -R -J -L -W1p,white -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1p,white,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${weight_cpt}" -DjBC+w1.9i/0.11i+h+o0/-0.65i \
	-Bxa0.2f0.1+l"Weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (f): result of blending over the converted envelope.
gmt grdimage "${merged}?z" -R -J -C"${value_cpt}" \
	-Bxf5 -Bya15f5 -BWSen+t"(f) Merged" \
	-X2.75i -O -K >> "${ps_file}"
gmt psxy "${converted}" -R -J -L -W1p,white -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1p,white,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" -DjBC+w1.9i/0.11i+h+o0/-0.65i \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex03_polygon_conversion"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex03_polygon_conversion"
