#!/usr/bin/env bash
#
# Compare regular and aggregate merging across multiple polygon supports.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex12-supports.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=0.5
projection=X3.0i/3.0i
secondary="${work_dir}/secondary.nc"
mergefile="${work_dir}/multiple_supports.merge2d"
regular="${work_dir}/regular.nc"
aggregate="${work_dir}/aggregate.nc"
ps_file="${work_dir}/ex12_multiple_supports.ps"
value_cpt="${work_dir}/values.cpt"
difference_cpt="${work_dir}/difference.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=14.97p

values=(9 7 5 8 6 4)
fills=(lightsteelblue lightsalmon palegreen khaki plum lightcyan)
bounds=(
	5/45/15/58 12/52/20/80 18/58/25/72
	55/95/12/55 48/92/22/86 45/94/28/76
)
primaries=()
supports=()
weights=()

# Each primary grid domain is its rectangular support. Several domains overlap
# so the regular mergefile order and aggregate normalization can be compared.
for index in 0 1 2 3 4 5; do
	primary="${work_dir}/primary$((index + 1)).nc"
	support="${work_dir}/support$((index + 1)).txt"
	weight="${work_dir}/weight$((index + 1)).nc"
	IFS=/ read -r west east south north <<< "${bounds[index]}"
	gmt grdmath -R${bounds[index]} -I${increment} ${values[index]} = "${primary}"
	printf "%s %s\n%s %s\n%s %s\n%s %s\n" \
		"${west}" "${south}" "${east}" "${south}" \
		"${east}" "${north}" "${west}" "${north}" > "${support}"
	primaries+=("${primary}")
	supports+=("${support}")
	weights+=("${weight}")
done
gmt grdmath -R${region} -I${increment} 1 = "${secondary}"

cat > "${mergefile}" <<- EOF
	${primaries[0]} ${secondary} - cosine/cosine 0.30
	${primaries[1]} ${secondary} - cosine/cosine 0.30
	${primaries[2]} ${secondary} - cosine/cosine 0.30
	${primaries[3]} ${secondary} - cosine/cosine 0.30
	${primaries[4]} ${secondary} - cosine/cosine 0.30
	${primaries[5]} ${secondary} - cosine/cosine 0.30
	${secondary} - - - -
	EOF

gmt merge2d "${mergefile}" -R${region} -I${increment} -G"${regular}"
gmt merge2d "${mergefile}" -R${region} -I${increment} -A -W \
	-G"${aggregate}"

# Generate each unnormalized support weight independently.
for index in 0 1 2 3 4 5; do
	single_mergefile="${work_dir}/primary$((index + 1)).merge2d"
	cat > "${single_mergefile}" <<- EOF
		${primaries[index]} ${secondary} - cosine/cosine 0.30
		${secondary} - - - -
		EOF
	gmt merge2d "${single_mergefile}" -R${region} -I${increment} -W+o \
		-G"${weights[index]}"
done

# Reconstruct the aggregate result from all primary and background weights.
gmt grdmath "${weights[0]}?weight" "${weights[1]}?weight" ADD \
	"${weights[2]}?weight" ADD "${weights[3]}?weight" ADD \
	"${weights[4]}?weight" ADD "${weights[5]}?weight" ADD = \
	"${work_dir}/weight_sum.nc"
gmt grdmath 1 "${work_dir}/weight_sum.nc" SUB 0 MAX = \
	"${work_dir}/background_weight.nc"
gmt grdmath "${work_dir}/weight_sum.nc" \
	"${work_dir}/background_weight.nc" ADD = "${work_dir}/weight_total.nc"

gmt grdmath "${weights[0]}?weight" ${values[0]} MUL \
	"${weights[1]}?weight" ${values[1]} MUL ADD \
	"${weights[2]}?weight" ${values[2]} MUL ADD \
	"${weights[3]}?weight" ${values[3]} MUL ADD \
	"${weights[4]}?weight" ${values[4]} MUL ADD \
	"${weights[5]}?weight" ${values[5]} MUL ADD \
	"${work_dir}/background_weight.nc" ADD \
	"${work_dir}/weight_total.nc" DIV = "${work_dir}/expected.nc"
gmt grdmath "${aggregate}?z" "${work_dir}/expected.nc" SUB = \
	"${work_dir}/aggregate_error.nc"
gmt grdinfo "${work_dir}/aggregate_error.nc" -C | \
	awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'

# Aggregate merging may differ from regular merging only where at least two
# primary grid domains overlap, including their zero-weight boundary nodes.
gmt grdmath -R${region} -I${increment} \
	X 5 GE X 45 LE MUL Y 15 GE MUL Y 58 LE MUL \
	X 12 GE X 52 LE MUL Y 20 GE MUL Y 80 LE MUL ADD \
	X 18 GE X 58 LE MUL Y 25 GE MUL Y 72 LE MUL ADD \
	X 55 GE X 95 LE MUL Y 12 GE MUL Y 55 LE MUL ADD \
	X 48 GE X 92 LE MUL Y 22 GE MUL Y 86 LE MUL ADD \
	X 45 GE X 94 LE MUL Y 28 GE MUL Y 76 LE MUL ADD = \
	"${work_dir}/support_count.nc"
gmt grdmath "${aggregate}?z" "${regular}" SUB = "${work_dir}/difference.nc"
gmt grdmath "${work_dir}/difference.nc" ABS \
	"${work_dir}/support_count.nc" 2 LT MUL = "${work_dir}/outside_difference.nc"
gmt grdinfo "${work_dir}/outside_difference.nc" -C | \
	awk '$7 > 1e-5 {exit 1}'
gmt grdinfo "${work_dir}/difference.nc" -C | \
	awk '$6 >= -1e-3 && $7 <= 1e-3 {exit 1}'
printf "0 95\n" | gmt grdtrack -G"${aggregate}?z" | \
	awk '$3 < 0.99999 || $3 > 1.00001 {exit 1}'

gmt makecpt -Cturbo -T1/9/1 -Z > "${value_cpt}"
gmt makecpt -Cpolar -T-6/6/0.5 -Z > "${difference_cpt}"

# Panel (a): primary grid domains and their constant values.
gmt psbasemap -P -R${region} -J${projection} -Bxa20f10 \
	-Bya20f10+l"Y" -BWSen+t"(a) Primary supports" \
	-X0.7i -Y4.8i -K > "${ps_file}"
for index in 0 1 2 3 4 5; do
	gmt psxy "${supports[index]}" -R -J -L -G"${fills[index]}" \
		-W1.5p,black -t35 -O -K >> "${ps_file}"
done
printf "12 23 P1 = 9\n22 72 P2 = 7\n48 65 P3 = 5\n87 20 P4 = 8\n68 82 P5 = 6\n84 70 P6 = 4\n" | \
	gmt pstext -R -J -F+f8p,Helvetica-Bold,black+jCM -O -K >> "${ps_file}"

# Panel (b): mergefile order controls every overlap in regular mode.
gmt grdimage "${regular}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(b) Regular merge" \
	-X3.75i -O -K >> "${ps_file}"
for support in "${supports[@]}"; do
	gmt psxy "${support}" -R -J -L -W1.5p,white,- -O -K >> "${ps_file}"
done

# Panel (c): -A normalizes all positive primary weights in each overlap.
gmt grdimage "${aggregate}?z" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(c) Aggregate merge (-A)" \
	-X-3.75i -Y-3.9i -O -K >> "${ps_file}"
for support in "${supports[@]}"; do
	gmt psxy "${support}" -R -J -L -W1.5p,white,- -O -K >> "${ps_file}"
done
gmt psscale -R -J -C"${value_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (d): differences are confined to overlapping primary supports.
gmt grdimage "${work_dir}/difference.nc" -R -J -C"${difference_cpt}" \
	-Bxa20f10+l"X" -Bya20f10 -BWSen+t"(d) Aggregate - regular" \
	-X3.75i -O -K >> "${ps_file}"
for support in "${supports[@]}"; do
	gmt psxy "${support}" -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"
done
gmt psscale -R -J -C"${difference_cpt}" -DjBC+w2.5i/0.12i+h+o0/-0.95i \
	-Bxa2f1+l"Difference" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex12_multiple_supports"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex12_multiple_supports"
