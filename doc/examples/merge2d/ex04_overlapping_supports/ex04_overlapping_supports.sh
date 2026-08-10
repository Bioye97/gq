#!/usr/bin/env bash
#
# Normalize overlapping 2-D primary supports with merge2d -A.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex04-overlap.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=0.5
projection=X2.2i/2.2i
primary1="${work_dir}/primary1.nc"
primary2="${work_dir}/primary2.nc"
secondary="${work_dir}/secondary.nc"
weight1="${work_dir}/weight1.nc"
weight2="${work_dir}/weight2.nc"
mergefile="${work_dir}/overlap.merge2d"
tiled="${work_dir}/tiled.nc"
regular="${work_dir}/regular.nc"
aggregate="${work_dir}/aggregate.nc"
ps_file="${work_dir}/ex04_overlapping_supports.ps"
value_cpt="${work_dir}/values.cpt"
difference_cpt="${work_dir}/difference.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=18.12p

# Two offset primary grids overlap from x = 35 to x = 65.
gmt grdmath -R10/65/15/85 -I${increment} 8 = "${primary1}"
gmt grdmath -R35/90/15/85 -I${increment} 5 = "${primary2}"
gmt grdmath -R${region} -I${increment} 2 = "${secondary}"

# Generate each raw support weight independently.
cat > "${work_dir}/primary1.merge2d" <<- EOF
	${primary1} ${secondary} - cosine/cosine 0.25
	${secondary} - - - -
	EOF
cat > "${work_dir}/primary2.merge2d" <<- EOF
	${primary2} ${secondary} - cosine/cosine 0.25
	${secondary} - - - -
	EOF
gmt merge2d "${work_dir}/primary1.merge2d" -R${region} -I${increment} \
	-W+o -G"${weight1}"
gmt merge2d "${work_dir}/primary2.merge2d" -R${region} -I${increment} \
	-W+o -G"${weight2}"

# Compare default tiling, ordinary paired merging, and aggregate normalization.
gmt merge2d "${primary1}" "${primary2}" "${secondary}" \
	-R${region} -I${increment} -G"${tiled}"
cat > "${mergefile}" <<- EOF
	${primary1} ${secondary} - cosine/cosine 0.25
	${primary2} ${secondary} - cosine/cosine 0.25
	${secondary} - - - -
	EOF
gmt merge2d "${mergefile}" -R${region} -I${increment} -G"${regular}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -A -W \
	-G"${aggregate}"

# Reconstruct the aggregate result from normalized primary and background weights.
gmt grdmath "${weight1}?weight" "${weight2}?weight" ADD = \
	"${work_dir}/weight_sum.nc"
gmt grdmath 1 "${work_dir}/weight_sum.nc" SUB 0 MAX = \
	"${work_dir}/background_weight.nc"
gmt grdmath "${work_dir}/weight_sum.nc" \
	"${work_dir}/background_weight.nc" ADD = "${work_dir}/weight_total.nc"
gmt grdmath "${weight1}?weight" 8 MUL "${weight2}?weight" 5 MUL ADD \
	"${work_dir}/background_weight.nc" 2 MUL ADD \
	"${work_dir}/weight_total.nc" DIV = "${work_dir}/expected.nc"
gmt grdmath "${aggregate}?z" "${work_dir}/expected.nc" SUB = \
	"${work_dir}/aggregate_error.nc"
gmt grdinfo "${work_dir}/aggregate_error.nc" -C | \
	awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'

gmt grdmath "${aggregate}?z" "${regular}" SUB = \
	"${work_dir}/difference.nc"
gmt grdinfo "${work_dir}/difference.nc" -C | \
	awk '$6 >= -1e-3 && $7 <= 1e-3 {exit 1}'

gmt makecpt -Cturbo -T2/8/1 -Z > "${value_cpt}"
gmt makecpt -Cpolar -T-3/3/0.5 -Z > "${difference_cpt}"

# Panel (a): primary supports and their shared secondary.
gmt psbasemap -P -R${region} -J${projection} -Bxa20f10+l"X" \
	-Bya20f10+l"Y" -BWSen+t"(a) Input supports" \
	-X0.65i -Y6.25i -K > "${ps_file}"
printf "10 15\n65 15\n65 85\n10 85\n" | \
	gmt psxy -R -J -L -Glightsteelblue -W1p,royalblue -t25 -O -K >> "${ps_file}"
printf "35 15\n90 15\n90 85\n35 85\n" | \
	gmt psxy -R -J -L -Glightsalmon -W1p,orangered -t25 -O -K >> "${ps_file}"
printf "25 52 Primary 1 = 8\n75 52 Primary 2 = 5\n50 6 Secondary = 2\n" | \
	gmt pstext -R -J -F+f8p,Helvetica,black+jCM -O -K >> "${ps_file}"

# Panel (b): direct inputs use first-available tiling without tapering.
gmt grdimage "${tiled}" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(b) Tiling (first-available)" \
	-X2.75i -O -K >> "${ps_file}"
printf "10 15\n65 15\n65 85\n10 85\n" | \
	gmt psxy -R -J -L -W1p,royalblue,- -O -K >> "${ps_file}"
printf "35 15\n90 15\n90 85\n35 85\n" | \
	gmt psxy -R -J -L -W1p,orangered,- -O -K >> "${ps_file}"

# Panel (c): regular paired merging retains the first primary in the overlap.
gmt grdimage "${regular}" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(c) Regular merge" \
	-X2.75i -O -K >> "${ps_file}"
printf "10 15\n65 15\n65 85\n10 85\n" | \
	gmt psxy -R -J -L -W1p,royalblue,- -O -K >> "${ps_file}"
printf "35 15\n90 15\n90 85\n35 85\n" | \
	gmt psxy -R -J -L -W1p,orangered,- -O -K >> "${ps_file}"

# Panel (d): -A normalizes both primary weights in their overlap.
gmt grdimage "${aggregate}?z" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(d) Aggregate merge (-A)" \
	-X-4.125i -Y-3.5i -O -K >> "${ps_file}"
printf "10 15\n65 15\n65 85\n10 85\n" | \
	gmt psxy -R -J -L -W1p,royalblue,- -O -K >> "${ps_file}"
printf "35 15\n90 15\n90 85\n35 85\n" | \
	gmt psxy -R -J -L -W1p,orangered,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" -DjBC+w1.8i/0.1i+h+o0/-0.95i \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (e): aggregate minus regular highlights the corrected overlap.
gmt grdimage "${work_dir}/difference.nc" -R -J -C"${difference_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(e) Aggregate - regular" \
	-X2.75i -O -K >> "${ps_file}"
printf "10 15\n65 15\n65 85\n10 85\n" | \
	gmt psxy -R -J -L -W1p,royalblue,- -O -K >> "${ps_file}"
printf "35 15\n90 15\n90 85\n35 85\n" | \
	gmt psxy -R -J -L -W1p,orangered,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${difference_cpt}" -DjBC+w1.8i/0.1i+h+o0/-0.95i \
	-Bxa1f0.5+l"Difference" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex04_overlapping_supports"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex04_overlapping_supports"
