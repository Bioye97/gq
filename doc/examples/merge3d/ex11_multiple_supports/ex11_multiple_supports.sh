#!/usr/bin/env bash
#
# Compare regular and aggregate 3-D merging across multiple supports.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex11-supports.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
zrange=0/100/1
horizontal_projection=X3.0i/3.0i
vertical_projection=X3.0i/-3.0i
secondary="${work_dir}/secondary.nc"
mergefile="${work_dir}/multiple_supports.merge3d"
regular="${work_dir}/regular.nc"
aggregate="${work_dir}/aggregate.nc"
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
z_bounds=(10/65 20/85 30/75 5/60 18/90 35/82)
primaries=()
horizontal_supports=()
vertical_supports=()
weights=()

# The six horizontal domains match the merge2d example. Their different z
# intervals create a second, independent overlap pattern in vertical section.
for index in 0 1 2 3 4 5; do
	primary="${work_dir}/primary$((index + 1)).nc"
	horizontal_support="${work_dir}/support$((index + 1))_horizontal.txt"
	vertical_support="${work_dir}/support$((index + 1))_vertical.txt"
	weight="${work_dir}/weight$((index + 1)).nc"
	IFS=/ read -r west east south north <<< "${bounds[index]}"
	IFS=/ read -r zlo zhi <<< "${z_bounds[index]}"

	for z in "${zlo}" "${zhi}"; do
		gmt grdmath -R${bounds[index]} -I${increment} ${values[index]} = \
			"${work_dir}/primary$((index + 1))_$(printf '%03d' "${z}").nc"
	done
	gmt grdinterpolate \
		"${work_dir}"/primary$((index + 1))_*.nc \
		-Z${zlo}/${zhi}/$((zhi - zlo)) -G"${primary}"

	printf "%s %s\n%s %s\n%s %s\n%s %s\n%s %s\n" \
		"${west}" "${south}" "${east}" "${south}" \
		"${east}" "${north}" "${west}" "${north}" \
		"${west}" "${south}" > "${horizontal_support}"
	printf "%s %s\n%s %s\n%s %s\n%s %s\n%s %s\n" \
		"${west}" "${zlo}" "${east}" "${zlo}" \
		"${east}" "${zhi}" "${west}" "${zhi}" \
		"${west}" "${zlo}" > "${vertical_support}"

	primaries+=("${primary}")
	horizontal_supports+=("${horizontal_support}")
	vertical_supports+=("${vertical_support}")
	weights+=("${weight}")
done

for z in 0 100; do
	gmt grdmath -R${region} -I${increment} 1 = \
		"${work_dir}/secondary_$(printf '%03d' "${z}").nc"
done
gmt grdinterpolate "${work_dir}"/secondary_*.nc -Z0/100/100 -G"${secondary}"

cat > "${mergefile}" <<- EOF
	${primaries[0]} ${secondary} - - cosine/cosine/cosine 0.30
	${primaries[1]} ${secondary} - - cosine/cosine/cosine 0.30
	${primaries[2]} ${secondary} - - cosine/cosine/cosine 0.30
	${primaries[3]} ${secondary} - - cosine/cosine/cosine 0.30
	${primaries[4]} ${secondary} - - cosine/cosine/cosine 0.30
	${primaries[5]} ${secondary} - - cosine/cosine/cosine 0.30
	${secondary} - - - - -
	EOF

gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-G"${regular}"
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-A -W -G"${aggregate}"

# Generate every unnormalized support weight independently.
for index in 0 1 2 3 4 5; do
	single_mergefile="${work_dir}/primary$((index + 1)).merge3d"
	cat > "${single_mergefile}" <<- EOF
		${primaries[index]} ${secondary} - - cosine/cosine/cosine 0.30
		${secondary} - - - - -
		EOF
	gmt merge3d "${single_mergefile}" -R${region} -I${increment} \
		-T${zrange} -W+o -G"${weights[index]}"
done

# Extract corresponding horizontal and vertical sections from every output.
for name in regular aggregate; do
	gmt grdconvert "${work_dir}/${name}.nc?cube[50]" \
		"${work_dir}/${name}_horizontal.nc"
	gmt grdcut "${work_dir}/${name}.nc?cube" -Ey50 \
		-G"${work_dir}/${name}_vertical.nc"
done
for index in 0 1 2 3 4 5; do
	gmt grdconvert "${weights[index]}?weight[50]" \
		"${work_dir}/weight$((index + 1))_horizontal.nc"
	gmt grdcut "${weights[index]}?weight" -Ey50 \
		-G"${work_dir}/weight$((index + 1))_vertical.nc"
done

# Reconstruct aggregate values from all primary and background weights in
# both sections, then confirm that regular and aggregate results differ.
for view in horizontal vertical; do
	gmt grdmath "${work_dir}/weight1_${view}.nc" \
		"${work_dir}/weight2_${view}.nc" ADD \
		"${work_dir}/weight3_${view}.nc" ADD \
		"${work_dir}/weight4_${view}.nc" ADD \
		"${work_dir}/weight5_${view}.nc" ADD \
		"${work_dir}/weight6_${view}.nc" ADD = \
		"${work_dir}/weight_sum_${view}.nc"
	gmt grdmath 1 "${work_dir}/weight_sum_${view}.nc" SUB 0 MAX = \
		"${work_dir}/background_weight_${view}.nc"
	gmt grdmath "${work_dir}/weight_sum_${view}.nc" \
		"${work_dir}/background_weight_${view}.nc" ADD = \
		"${work_dir}/weight_total_${view}.nc"

	gmt grdmath "${work_dir}/weight1_${view}.nc" ${values[0]} MUL \
		"${work_dir}/weight2_${view}.nc" ${values[1]} MUL ADD \
		"${work_dir}/weight3_${view}.nc" ${values[2]} MUL ADD \
		"${work_dir}/weight4_${view}.nc" ${values[3]} MUL ADD \
		"${work_dir}/weight5_${view}.nc" ${values[4]} MUL ADD \
		"${work_dir}/weight6_${view}.nc" ${values[5]} MUL ADD \
		"${work_dir}/background_weight_${view}.nc" ADD \
		"${work_dir}/weight_total_${view}.nc" DIV = \
		"${work_dir}/expected_${view}.nc"
	gmt grdmath "${work_dir}/aggregate_${view}.nc" \
		"${work_dir}/expected_${view}.nc" SUB = \
		"${work_dir}/aggregate_error_${view}.nc"
	gmt grdinfo "${work_dir}/aggregate_error_${view}.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
	gmt grdmath "${work_dir}/aggregate_${view}.nc" \
		"${work_dir}/regular_${view}.nc" SUB = \
		"${work_dir}/difference_${view}.nc"
	gmt grdinfo "${work_dir}/difference_${view}.nc" -C | \
		awk '$6 >= -1e-3 && $7 <= 1e-3 {exit 1}'
done

# Aggregate and regular merging may differ only where at least two supports
# overlap in each plotted section.
gmt grdmath -R${region} -I${increment} \
	X 5 GE X 45 LE MUL Y 15 GE MUL Y 58 LE MUL \
	X 12 GE X 52 LE MUL Y 20 GE MUL Y 80 LE MUL ADD \
	X 18 GE X 58 LE MUL Y 25 GE MUL Y 72 LE MUL ADD \
	X 55 GE X 95 LE MUL Y 12 GE MUL Y 55 LE MUL ADD \
	X 48 GE X 92 LE MUL Y 22 GE MUL Y 86 LE MUL ADD \
	X 45 GE X 94 LE MUL Y 28 GE MUL Y 76 LE MUL ADD = \
	"${work_dir}/support_count_horizontal.nc"
gmt grdmath -R${region} -I${increment} \
	X 5 GE X 45 LE MUL Y 10 GE MUL Y 65 LE MUL \
	X 12 GE X 52 LE MUL Y 20 GE MUL Y 85 LE MUL ADD \
	X 18 GE X 58 LE MUL Y 30 GE MUL Y 75 LE MUL ADD \
	X 55 GE X 95 LE MUL Y 5 GE MUL Y 60 LE MUL ADD \
	X 48 GE X 92 LE MUL Y 18 GE MUL Y 90 LE MUL ADD \
	X 45 GE X 94 LE MUL Y 35 GE MUL Y 82 LE MUL ADD = \
	"${work_dir}/support_count_vertical.nc"
for view in horizontal vertical; do
	gmt grdmath "${work_dir}/difference_${view}.nc" ABS \
		"${work_dir}/support_count_${view}.nc" 2 LT MUL = \
		"${work_dir}/outside_difference_${view}.nc"
	gmt grdinfo "${work_dir}/outside_difference_${view}.nc" -C | \
		awk '$7 > 1e-5 {exit 1}'
done
printf "0 95\n" | gmt grdtrack -G"${work_dir}/aggregate_horizontal.nc" | \
	awk '$3 < 0.99999 || $3 > 1.00001 {exit 1}'
printf "0 95\n" | gmt grdtrack -G"${work_dir}/aggregate_vertical.nc" | \
	awk '$3 < 0.99999 || $3 > 1.00001 {exit 1}'

gmt makecpt -Cturbo -T1/9/1 -Z > "${value_cpt}"
gmt makecpt -Cpolar -T-6/6/0.5 -Z > "${difference_cpt}"

plot_figure() {
	local view=$1
	local projection=$2
	local axis_label=$3
	local section_label=$4
	local output_name=$5
	local ps_file="${work_dir}/${output_name}.ps"
	local support_list
	if [[ "${view}" == horizontal ]]; then
		support_list=("${horizontal_supports[@]}")
	else
		support_list=("${vertical_supports[@]}")
	fi

	# Panel (a): primary domains and their constant values.
	gmt psbasemap -P -R${region} -J${projection} \
		-Bxa20f10+l"X" -Bya20f10+l"${axis_label}" \
		"-BWSen+t(a) Primary supports: ${section_label}" \
		-X0.7i -Y5.5i -K > "${ps_file}"
	for index in 0 1 2 3 4 5; do
		gmt psxy "${support_list[index]}" -R -J -L -G"${fills[index]}" \
			-W1.5p,black -t35 -O -K >> "${ps_file}"
	done
	if [[ "${view}" == horizontal ]]; then
		printf "12 23 P1 = 9\n22 72 P2 = 7\n48 65 P3 = 5\n87 20 P4 = 8\n68 82 P5 = 6\n84 70 P6 = 4\n" | \
			gmt pstext -R -J -F+f8p,Helvetica-Bold,black+jCM \
			-O -K >> "${ps_file}"
		printf "0 50\n100 50\n" | \
			gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
	else
		printf "11 17 P1 = 9\n20 78 P2 = 7\n49 68 P3 = 5\n86 13 P4 = 8\n60 85 P5 = 6\n84 74 P6 = 4\n" | \
			gmt pstext -R -J -F+f8p,Helvetica-Bold,black+jCM \
			-O -K >> "${ps_file}"
		printf "0 50\n100 50\n" | \
			gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
	fi

	# Panel (b): mergefile order controls overlaps in regular mode.
	gmt grdimage "${work_dir}/regular_${view}.nc" -R -J -C"${value_cpt}" \
		-Bxa20f10+l"X" -Bya20f10 \
		"-BWSen+t(b) Regular merge: ${section_label}" \
		-X3.75i -O -K >> "${ps_file}"
	for support in "${support_list[@]}"; do
		gmt psxy "${support}" -R -J -L -W1.5p,white,- \
			-O -K >> "${ps_file}"
	done

	# Panel (c): -A normalizes all positive primary weights in each overlap.
	gmt grdimage "${work_dir}/aggregate_${view}.nc" -R -J -C"${value_cpt}" \
		-Bxa20f10+l"X" -Bya20f10+l"${axis_label}" \
		"-BWSen+t(c) Aggregate merge (-A): ${section_label}" \
		-X-3.75i -Y-4.15i -O -K >> "${ps_file}"
	for support in "${support_list[@]}"; do
		gmt psxy "${support}" -R -J -L -W1.5p,white,- \
			-O -K >> "${ps_file}"
	done
	gmt psscale -R -J -C"${value_cpt}" \
		-DjBC+w2.5i/0.12i+h+o0/-1.0i -Bxa2f1+l"Value" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-O -K >> "${ps_file}"

	# Panel (d): differences remain confined to overlapping supports.
	gmt grdimage "${work_dir}/difference_${view}.nc" \
		-R -J -C"${difference_cpt}" -Bxa20f10+l"X" -Bya20f10 \
		"-BWSen+t(d) Aggregate - regular: ${section_label}" \
		-X3.75i -O -K >> "${ps_file}"
	for support in "${support_list[@]}"; do
		gmt psxy "${support}" -R -J -L -W1.5p,black,- \
			-O -K >> "${ps_file}"
	done
	gmt psscale -R -J -C"${difference_cpt}" \
		-DjBC+w2.5i/0.12i+h+o0/-1.0i -Bxa2f1+l"Difference" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} \
		-O >> "${ps_file}"

	gmt psconvert "${ps_file}" -A+m0.1i -Tf -F"${script_dir}/${output_name}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/${output_name}"
}

plot_figure horizontal "${horizontal_projection}" Y "z = 50" \
	ex11_multiple_supports_horizontal
plot_figure vertical "${vertical_projection}" Z "y = 50" \
	ex11_multiple_supports_vertical
