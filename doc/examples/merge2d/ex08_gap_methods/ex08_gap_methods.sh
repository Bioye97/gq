#!/usr/bin/env bash
#
# Compare the interpolation methods for filling an internal grid gap.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex08-gaps.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
projection=X1.9i/1.9i
reference="${work_dir}/reference.nc"
gapped="${work_dir}/gapped.nc"
mergefile="${work_dir}/gap.merge2d"
nearest="${work_dir}/nearest.nc"
linear="${work_dir}/linear.nc"
average="${work_dir}/average.nc"
spline="${work_dir}/spline.nc"
minimum_curvature="${work_dir}/minimum_curvature.nc"
hole="${work_dir}/hole.txt"
value_cpt="${work_dir}/values.cpt"
ps_file="${work_dir}/ex08_gap_methods.ps"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=11.9p

# Build a smooth reference field, then remove a circular internal region.
gmt grdmath -R${region} -I${increment} \
	X 3 MUL SIND Y 2 MUL COSD MUL 2 MUL X 0.03 MUL ADD 5 ADD = \
	"${reference}"
gmt grdmath \
	X 50 SUB DUP MUL Y 50 SUB DUP MUL ADD SQRT 18 LE \
	NaN "${reference}" IFELSE = "${gapped}"
awk 'BEGIN {
	pi = atan2(0, -1)
	for (angle = 0; angle <= 360; angle += 2) {
		radians = angle * pi / 180
		printf "%.12g %.12g\n", 50 + 18 * cos(radians), 50 + 18 * sin(radians)
	}
}' > "${hole}"

cat > "${mergefile}" <<- EOF
	${gapped} - - - -
	EOF

gmt merge2d "${mergefile}" -R${region} -I${increment} -Hn \
	-G"${nearest}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -Hl \
	-G"${linear}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -Ha30/8 \
	-G"${average}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -Hs0.25 \
	-G"${spline}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -Hm0.25 \
	-G"${minimum_curvature}"

# Every method must fill the hole and preserve all original data nodes.
for result in "${nearest}" "${linear}" "${average}" "${spline}" \
	"${minimum_curvature}"; do
	name=$(basename "${result}" .nc)
	gmt grdmath "${result}" ISNAN = "${work_dir}/${name}_missing.nc"
	gmt grdinfo "${work_dir}/${name}_missing.nc" -C | \
		awk '$7 != 0 {exit 1}'
	gmt grdmath "${result}" "${reference}" SUB \
		"${gapped}" ISNAN 0 EQ MUL = "${work_dir}/${name}_outside.nc"
	gmt grdinfo "${work_dir}/${name}_outside.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
done

# Confirm that the interpolation choices produce distinct reconstructions.
gmt grdmath "${nearest}" "${linear}" SUB ABS = \
	"${work_dir}/nearest_linear.nc"
gmt grdinfo "${work_dir}/nearest_linear.nc" -C | \
	awk '$7 <= 0.01 {exit 1}'
gmt grdmath "${spline}" "${minimum_curvature}" SUB ABS = \
	"${work_dir}/smooth_methods.nc"
gmt grdinfo "${work_dir}/smooth_methods.nc" -C | \
	awk '$7 <= 0.001 {exit 1}'

gmt makecpt -Cturbo -T3/10/0.5 -Z > "${value_cpt}"

# Panel (a): the complete field provides the interpolation reference.
gmt grdimage "${reference}" -P -R${region} -J${projection} -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10+l"Y" -BWSen+t"(a) Reference field" \
	-X0.85i -Y7.05i -K > "${ps_file}"
gmt psxy "${hole}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Panel (b): the input field contains the circular gap.
gmt grdimage "${gapped}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Byf10 -BWSen+t"(b) Gapped field" \
	-X2.45i -O -K >> "${ps_file}"
gmt psxy "${hole}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Panel (c): nearest-neighbor interpolation.
gmt grdimage "${nearest}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Byf10 -BWSen+t"(c) Nearest neighbor" \
	-X2.45i -O -K >> "${ps_file}"
gmt psxy "${hole}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Panel (d): linear interpolation over a Delaunay triangulation.
gmt grdimage "${linear}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10+l"Y" -BWSen+t"(d) Linear Delaunay" \
	-X-4.9i -Y-2.8i -O -K >> "${ps_file}"
gmt psxy "${hole}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Panel (e): local weighted averaging with radius 30 and eight sectors.
gmt grdimage "${average}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Byf10 -BWSen+t"(e) Weighted average" \
	-X2.45i -O -K >> "${ps_file}"
gmt psxy "${hole}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Panel (f): spline interpolation with tension 0.25.
gmt grdimage "${spline}" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Byf10 -BWSen+t"(f) Spline" \
	-X2.45i -O -K >> "${ps_file}"
gmt psxy "${hole}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Panel (g): minimum-curvature interpolation with tension 0.25.
gmt grdimage "${minimum_curvature}" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(g) Minimum curvature" \
	-X-2.45i -Y-2.8i -O -K >> "${ps_file}"
gmt psxy "${hole}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Use one color scale for the shared value range.
gmt psscale -R -J -C"${value_cpt}" -DjBC+w4.2i/0.12i+h+o0/-1.2i \
	-Bxa1f0.5+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex08_gap_methods"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex08_gap_methods"
