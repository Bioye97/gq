#!/usr/bin/env bash
#
# Demonstrate gap-size limits and preservation of edge-connected gaps.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex09-limits.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
projection=X2.9i/2.9i
reference="${work_dir}/reference.nc"
small_gap="${work_dir}/small_gap.nc"
internal_gaps="${work_dir}/internal_gaps.nc"
gapped="${work_dir}/gapped.nc"
mergefile="${work_dir}/gaps.merge2d"
limited="${work_dir}/limited.nc"
unlimited="${work_dir}/unlimited.nc"
small_outline="${work_dir}/small_outline.txt"
large_outline="${work_dir}/large_outline.txt"
edge_outline="${work_dir}/edge_outline.txt"
value_cpt="${work_dir}/values.cpt"
ps_file="${work_dir}/ex09_gap_limits.ps"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=10.7p

# Remove an 11-node-wide circle, a 29-node-wide circle, and an edge rectangle.
gmt grdmath -R${region} -I${increment} \
	X 2 MUL SIND Y 3 MUL COSD ADD X 0.02 MUL ADD 6 ADD = \
	"${reference}"
gmt grdmath X 25 SUB DUP MUL Y 70 SUB DUP MUL ADD SQRT 5 LE \
	NaN "${reference}" IFELSE = "${small_gap}"
gmt grdmath X 65 SUB DUP MUL Y 55 SUB DUP MUL ADD SQRT 14 LE \
	NaN "${small_gap}" IFELSE = "${internal_gaps}"
gmt grdmath X 18 LE Y 10 GE MUL Y 25 LE MUL \
	NaN "${internal_gaps}" IFELSE = "${gapped}"

awk 'BEGIN {
	pi = atan2(0, -1)
	for (angle = 0; angle <= 360; angle += 3) {
		radians = angle * pi / 180
		printf "%.12g %.12g\n", 25 + 5 * cos(radians), 70 + 5 * sin(radians)
	}
}' > "${small_outline}"
awk 'BEGIN {
	pi = atan2(0, -1)
	for (angle = 0; angle <= 360; angle += 3) {
		radians = angle * pi / 180
		printf "%.12g %.12g\n", 65 + 14 * cos(radians), 55 + 14 * sin(radians)
	}
}' > "${large_outline}"
printf "0 10\n18 10\n18 25\n0 25\n" > "${edge_outline}"

cat > "${mergefile}" <<- EOF
	${gapped} - - - -
	EOF

# A bare -H uses linear Delaunay interpolation; +m limits both gap spans.
gmt merge2d "${mergefile}" -R${region} -I${increment} -H+m12 \
	-G"${limited}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -Hl \
	-G"${unlimited}"

# The limited result fills only the small hole.
printf "25 70\n65 55\n10 18\n" | \
	gmt grdtrack -G"${limited}" > "${work_dir}/limited_samples.txt"
awk 'NR == 1 && tolower($3) == "nan" {exit 1}
	 NR == 2 && tolower($3) != "nan" {exit 1}
	 NR == 3 && tolower($3) != "nan" {exit 1}' \
	"${work_dir}/limited_samples.txt"

# The unrestricted result fills both enclosed holes but not the edge gap.
printf "25 70\n65 55\n10 18\n" | \
	gmt grdtrack -G"${unlimited}" > "${work_dir}/unlimited_samples.txt"
awk 'NR == 1 && tolower($3) == "nan" {exit 1}
	 NR == 2 && tolower($3) == "nan" {exit 1}
	 NR == 3 && tolower($3) != "nan" {exit 1}' \
	"${work_dir}/unlimited_samples.txt"

# Gap filling must not modify original data nodes.
for result in "${limited}" "${unlimited}"; do
	name=$(basename "${result}" .nc)
	gmt grdmath "${result}" "${reference}" SUB \
		"${gapped}" ISNAN 0 EQ MUL = "${work_dir}/${name}_outside.nc"
	gmt grdinfo "${work_dir}/${name}_outside.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
done

gmt makecpt -Cturbo -T3/10/0.5 -Z > "${value_cpt}"

# Panel (a): the complete field before introducing gaps.
gmt grdimage "${reference}" -P -R${region} -J${projection} -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10+l"Y" -BWSen+t"(a) Reference field" \
	-X0.8i -Y5.1i -K > "${ps_file}"
gmt psxy "${small_outline}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${large_outline}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${edge_outline}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"

# Panel (b): all three gaps in the merge2d input.
gmt grdimage "${gapped}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(b) Gapped field" \
	-X3.55i -O -K >> "${ps_file}"
gmt psxy "${small_outline}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${large_outline}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${edge_outline}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"

# Panel (c): +m12 rejects holes wider than 12 nodes in either dimension.
gmt grdimage "${limited}" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(c) Maximum span: 12 nodes" \
	-X-3.55i -Y-3.65i -O -K >> "${ps_file}"
gmt psxy "${small_outline}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${large_outline}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${edge_outline}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"

# Panel (d): unrestricted -Hl fills every enclosed hole.
gmt grdimage "${unlimited}" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(d) All internal gaps" \
	-X3.55i -O -K >> "${ps_file}"
gmt psxy "${small_outline}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${large_outline}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${edge_outline}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"

gmt psscale -R -J -C"${value_cpt}" -DjBC+w5.2i/0.12i+h+o0/-1.1i \
	-Bxa1f0.5+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -X-1.775i -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex09_gap_limits"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex09_gap_limits"
