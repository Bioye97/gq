#!/usr/bin/env bash
#
# Blend a primary grid into a secondary grid using a 2-D cosine taper.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex02-blending.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=0.5
projection=X3.15i/3.15i
primary="${work_dir}/primary.nc"
primary_full="${work_dir}/primary_full.nc"
secondary="${work_dir}/secondary.nc"
mergefile="${work_dir}/blend.merge2d"
merged="${work_dir}/merged.nc"
ps_file="${work_dir}/ex02_blending.ps"
value_cpt="${work_dir}/values.cpt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=15.37p

# Generate smooth primary and secondary surfaces.
gmt grdmath -R20/80/20/80 -I${increment} \
	X 50 SUB 12 DIV 2 POW Y 50 SUB 15 DIV 2 POW ADD NEG EXP 5 MUL \
	X 8 DIV SIN 0.5 MUL ADD 5 ADD = "${primary}"
gmt grdmath -R${region} -I${increment} \
	X 50 SUB 12 DIV 2 POW Y 50 SUB 15 DIV 2 POW ADD NEG EXP 5 MUL \
	X 8 DIV SIN 0.5 MUL ADD 5 ADD = "${primary_full}"
gmt grdmath -R${region} -I${increment} \
	X 40 DIV Y 50 DIV ADD X 15 DIV COS Y 18 DIV SIN MUL 0.6 MUL ADD 2 ADD = \
	"${secondary}"

# Blend within the primary domain and tile the secondary everywhere else.
cat > "${mergefile}" <<- EOF
	${primary} ${secondary} - cosine/cosine 0.25
	${secondary} - - - -
	EOF
gmt merge2d "${mergefile}" -R${region} -I${increment} -W -G"${merged}"

# Verify the weighted combination at every output node.
gmt grdmath "${merged}?weight" "${primary_full}" MUL \
	1 "${merged}?weight" SUB "${secondary}" MUL ADD = \
	"${work_dir}/expected.nc"
gmt grdmath "${merged}?z" "${work_dir}/expected.nc" SUB = \
	"${work_dir}/difference.nc"
gmt grdinfo "${work_dir}/difference.nc" -C | \
	awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
gmt grdinfo "${merged}?weight" -C | \
	awk '$6 < 0 || $7 > 1 {exit 1}'

gmt makecpt -Cturbo -T1/11/1 -Z > "${value_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

# Panel (a): primary grid and its rectangular support.
gmt grdimage "${primary}" -P -R${region} -J${projection} -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10+l"Y" -BWSen+t"(a) Primary" \
	-X0.8i -Y5.25i -K > "${ps_file}"
printf "20 20\n80 20\n80 80\n20 80\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (b): secondary grid covering the output domain.
gmt grdimage "${secondary}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(b) Secondary" \
	-X3.75i -O -K >> "${ps_file}"
printf "20 20\n80 20\n80 80\n20 80\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"

# Panel (c): separable cosine tapers on all four sides.
gmt grdimage "${merged}?weight" -R -J -C"${weight_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(c) Merging weight" \
	-X-3.75i -Y-3.85i -O -K >> "${ps_file}"
printf "20 20\n80 20\n80 80\n20 80\n" | \
	gmt psxy -R -J -L -W1p,orangered,- -O -K >> "${ps_file}"
printf "35 35\n65 35\n65 65\n35 65\n" | \
	gmt psxy -R -J -L -W1p,royalblue,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${weight_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa0.2f0.1+l"Weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (d): weighted primary and secondary values form the merged grid.
gmt grdimage "${merged}?z" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(d) Merged" \
	-X3.75i -O -K >> "${ps_file}"
printf "20 20\n80 20\n80 80\n20 80\n" | \
	gmt psxy -R -J -L -W1p,black,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex02_blending"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex02_blending"
