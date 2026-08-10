#!/usr/bin/env bash
#
# Compare merge3d clobber modes using horizontal and vertical slices.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex01-clobber.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=0/10/0/10
increment=0.2
zrange=0/10/0.2
horizontal_projection=X1.45i/1.45i
vertical_projection=X1.45i/-1.45i
ps_file="${work_dir}/ex01_clobber.ps"
cpt="${work_dir}/values.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=9.8p

# Cube A is defined over 0/7 in x, y, and z, with A = x + y + z - 10.5.
for z in 0 1 2 3 4 5 6 7; do
	gmt grdmath -R0/7/0/7 -I${increment} X Y ADD ${z} ADD 10.5 SUB = \
		"${work_dir}/cube_a_$(printf '%02d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/cube_a_*.nc -Z0/7/1 \
	-G"${work_dir}/cube_a.nc"

# Cube B is defined over 3/10, with B = 19.5 - x - y - z.
for z in 3 4 5 6 7 8 9 10; do
	gmt grdmath -R3/10/3/10 -I${increment} 19.5 X SUB Y SUB ${z} SUB = \
		"${work_dir}/cube_b_$(printf '%02d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/cube_b_*.nc -Z3/10/1 \
	-G"${work_dir}/cube_b.nc"

# Direct cube lists use first-value clobbering by default.
gmt merge3d "${work_dir}/cube_a.nc" "${work_dir}/cube_b.nc" \
	-R${region} -I${increment} -T${zrange} -G"${work_dir}/default.nc"
gmt merge3d "${work_dir}/cube_a.nc" "${work_dir}/cube_b.nc" \
	-R${region} -I${increment} -T${zrange} -Cf \
	-G"${work_dir}/first.nc"
gmt merge3d "${work_dir}/cube_a.nc" "${work_dir}/cube_b.nc" \
	-R${region} -I${increment} -T${zrange} -Co \
	-G"${work_dir}/last.nc"
gmt merge3d "${work_dir}/cube_a.nc" "${work_dir}/cube_b.nc" \
	-R${region} -I${increment} -T${zrange} -Cl \
	-G"${work_dir}/lower.nc"
gmt merge3d "${work_dir}/cube_a.nc" "${work_dir}/cube_b.nc" \
	-R${region} -I${increment} -T${zrange} -Cu \
	-G"${work_dir}/upper.nc"

# Extract a horizontal slice at z = 5 from every cube.
for name in cube_a cube_b default first last lower upper; do
	gmt grdinterpolate "${work_dir}/${name}.nc" -T5 \
		-G"${work_dir}/${name}_horizontal.nc"
done

# Keep the input sections within their native x domains to avoid sampling
# outside either cube. The merged outputs span the complete output domain.
gmt grdinterpolate "${work_dir}/cube_a.nc" -E0/5/7/5+i${increment} \
	-G"${work_dir}/cube_a_vertical.nc"
gmt grdinterpolate "${work_dir}/cube_b.nc" -E3/5/10/5+i${increment} \
	-G"${work_dir}/cube_b_vertical.nc"
gmt grdedit "${work_dir}/cube_b_vertical.nc" -R3/10/3/10
for name in default first last lower upper; do
	gmt grdinterpolate "${work_dir}/${name}.nc" -E0/5/10/5+i${increment} \
		-G"${work_dir}/${name}_vertical.nc"
done

# Confirm that the default and explicit first-value modes agree in both views.
for view in horizontal vertical; do
	gmt grdmath "${work_dir}/default_${view}.nc" \
		"${work_dir}/first_${view}.nc" SUB = \
		"${work_dir}/difference_${view}.nc"
	gmt grdinfo "${work_dir}/difference_${view}.nc" -C | \
		awk '$6 != 0 || $7 != 0 {exit 1}'
done

cat > "${work_dir}/cube_a_outline.txt" <<- EOF
	0 0
	7 0
	7 7
	0 7
	0 0
	EOF
cat > "${work_dir}/cube_b_outline.txt" <<- EOF
	3 3
	10 3
	10 10
	3 10
	3 3
	EOF

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cpolar -T-11/11/1 -Z > "${cpt}"

plot_horizontal() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 xaxis=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${horizontal_projection} -C"${cpt}" \
		"${xaxis}" "${yaxis}" "-BWSen+t${title}" -X${xshift} -Y${yshift} \
		-O -K >> "${ps_file}"
	gmt psxy "${work_dir}/cube_a_outline.txt" -R -J -W1p,black \
		-O -K >> "${ps_file}"
	gmt psxy "${work_dir}/cube_b_outline.txt" -R -J -W1p,black,-- \
		-O -K >> "${ps_file}"
}

plot_vertical() {
	local grid=$1 title=$2 xshift=$3 yshift=$4 xaxis=$5 yaxis=$6
	gmt grdimage "${grid}" -R${region} -J${vertical_projection} -C"${cpt}" \
		"${xaxis}" "${yaxis}" "-BWSen+t${title}" -X${xshift} -Y${yshift} \
		-O -K >> "${ps_file}"
	gmt psxy "${work_dir}/cube_a_outline.txt" -R -J -W1p,black \
		-O -K >> "${ps_file}"
	gmt psxy "${work_dir}/cube_b_outline.txt" -R -J -W1p,black,-- \
		-O -K >> "${ps_file}"
}

# First row: horizontal and vertical views of the two input cubes.
gmt grdimage "${work_dir}/cube_a_horizontal.nc" -P -R${region} \
	-J${horizontal_projection} -C"${cpt}" -Bxa2f1+l"X" -Bya2f1+l"Y" \
	-BWSen+t"(a) Cube A: z = 5" -X0.55i -Y6.4i -K > "${ps_file}"
printf "0 5\n10 5\n" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
gmt grdimage "${work_dir}/cube_b_horizontal.nc" -R -J -C"${cpt}" \
	-Bxa2f1+l"X" -Bya2f1 -BWSen+t"(b) Cube B: z = 5" \
	-X1.8i -O -K >> "${ps_file}"
printf "0 5\n10 5\n" | \
	gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
gmt grdimage "${work_dir}/cube_a_vertical.nc" -R${region} \
	-J${vertical_projection} -C"${cpt}" -Bxa2f1+l"X" -Bya2f1+l"Z" \
	-BWSen+t"(c) Cube A: y = 5" -X1.8i -O -K >> "${ps_file}"
gmt grdimage "${work_dir}/cube_b_vertical.nc" -R -J -C"${cpt}" \
	-Bxa2f1+l"X" -Bya2f1 -BWSen+t"(d) Cube B: y = 5" \
	-X1.8i -O -K >> "${ps_file}"

# Second row: horizontal slices through the four clobber results.
plot_horizontal "${work_dir}/first_horizontal.nc" "(e) Default / -Cf (first)" \
	-5.4i -2.35i -Bxa2f1+lX -Bya2f1+lY
plot_horizontal "${work_dir}/last_horizontal.nc" "(f) -Co (last)" \
	1.8i 0i -Bxa2f1+lX -Bya2f1
plot_horizontal "${work_dir}/lower_horizontal.nc" "(g) -Cl (lower)" \
	1.8i 0i -Bxa2f1+lX -Bya2f1
plot_horizontal "${work_dir}/upper_horizontal.nc" "(h) -Cu (upper)" \
	1.8i 0i -Bxa2f1+lX -Bya2f1

# Third row: matching vertical sections along y = 5.
plot_vertical "${work_dir}/first_vertical.nc" "(i) Default / -Cf (first)" \
	-5.4i -2.35i -Bxa2f1+lX -Bya2f1+lZ
plot_vertical "${work_dir}/last_vertical.nc" "(j) -Co (last)" \
	1.8i 0i -Bxa2f1+lX -Bya2f1
plot_vertical "${work_dir}/lower_vertical.nc" "(k) -Cl (lower)" \
	1.8i 0i -Bxa2f1+lX -Bya2f1
plot_vertical "${work_dir}/upper_vertical.nc" "(l) -Cu (upper)" \
	1.8i 0i -Bxa2f1+lX -Bya2f1

gmt psscale -R -J -C"${cpt}" -Dx-5.4i/-0.75i+w6.85i/0.13i+h \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A+m0.1i -Tf -F"${script_dir}/ex01_clobber"
gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex01_clobber"
