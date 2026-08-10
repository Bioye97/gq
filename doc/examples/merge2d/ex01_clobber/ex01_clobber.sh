#!/usr/bin/env bash
#
# Compare merge2d clobber modes.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex01-clobber.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/10/0/10
increment=0.1
projection=X2.55i/2.55i
ps_file="${work_dir}/ex01_clobber.ps"
cpt="${work_dir}/values.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=11.46p

# The two surfaces cross within their shared 3/7/3/7 region.
gmt grdmath -R0/7/0/7 -I${increment} X Y ADD 7 SUB = \
	"${work_dir}/grid_a.nc"
gmt grdmath -R3/10/3/10 -I${increment} 13 X SUB Y SUB = \
	"${work_dir}/grid_b.nc"

# Direct grid lists use first-value clobbering by default.
gmt merge2d "${work_dir}/grid_a.nc" "${work_dir}/grid_b.nc" \
	-R${region} -I${increment} -G"${work_dir}/default.nc"
gmt merge2d "${work_dir}/grid_a.nc" "${work_dir}/grid_b.nc" \
	-R${region} -I${increment} -Cf -G"${work_dir}/first.nc"
gmt merge2d "${work_dir}/grid_a.nc" "${work_dir}/grid_b.nc" \
	-R${region} -I${increment} -Co -G"${work_dir}/last.nc"
gmt merge2d "${work_dir}/grid_a.nc" "${work_dir}/grid_b.nc" \
	-R${region} -I${increment} -Cl -G"${work_dir}/lower.nc"
gmt merge2d "${work_dir}/grid_a.nc" "${work_dir}/grid_b.nc" \
	-R${region} -I${increment} -Cu -G"${work_dir}/upper.nc"

# Confirm that the default and explicit first-value modes agree.
gmt grdmath "${work_dir}/default.nc" "${work_dir}/first.nc" SUB = \
	"${work_dir}/difference.nc"
gmt grdinfo "${work_dir}/difference.nc" -C | \
	awk '$6 != 0 || $7 != 0 {exit 1}'

gmt makecpt -Cpolar -T-7/7/1 -Z > "${cpt}"

# Panel (a): first input grid.
gmt grdimage "${work_dir}/grid_a.nc" -P -R${region} -J${projection} \
	-C"${cpt}" -Bxa2f1 -Bya2f1+l"Y" -BWSen+t"(a) Grid A" \
	-X0.8i -Y8.4i -K > "${ps_file}"
printf "3 3\n7 3\n7 7\n3 7\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (b): second input grid.
gmt grdimage "${work_dir}/grid_b.nc" -R -J -C"${cpt}" \
	-Bxa2f1 -Bya2f1 -BWSen+t"(b) Grid B" -X3.3i -O -K >> "${ps_file}"
printf "3 3\n7 3\n7 7\n3 7\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (c): the first input has precedence in the overlap.
gmt grdimage "${work_dir}/first.nc" -R -J -C"${cpt}" \
	-Bxa2f1 -Bya2f1+l"Y" -BWSen+t"(c) Default / -Cf (first)" \
	-X-3.3i -Y-3.65i -O -K >> "${ps_file}"
printf "3 3\n7 3\n7 7\n3 7\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (d): the last input has precedence in the overlap.
gmt grdimage "${work_dir}/last.nc" -R -J -C"${cpt}" \
	-Bxa2f1 -Bya2f1 -BWSen+t"(d) -Co (last)" -X3.3i -O -K >> "${ps_file}"
printf "3 3\n7 3\n7 7\n3 7\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (e): retain the lower value at each overlapping node.
gmt grdimage "${work_dir}/lower.nc" -R -J -C"${cpt}" \
	-Bxa2f1+l"X" -Bya2f1+l"Y" -BWSen+t"(e) -Cl (lower)" \
	-X-3.3i -Y-3.65i -O -K >> "${ps_file}"
printf "3 3\n7 3\n7 7\n3 7\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (f): retain the higher value at each overlapping node.
gmt grdimage "${work_dir}/upper.nc" -R -J -C"${cpt}" \
	-Bxa2f1+l"X" -Bya2f1 -BWSen+t"(f) -Cu (upper)" \
	-X3.3i -O -K >> "${ps_file}"
printf "3 3\n7 3\n7 7\n3 7\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

gmt psscale -R -J -C"${cpt}" -DjBC+w4.5i/0.14i+h+o-1.65i/-1.0i \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex01_clobber"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex01_clobber"
