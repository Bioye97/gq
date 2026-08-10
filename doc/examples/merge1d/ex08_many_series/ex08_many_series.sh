#!/usr/bin/env bash
#
# Merge seven constant primary series and one full-domain secondary.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex08-many.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

range=0/100/0.1
region=0/100/0/8.8
projection=X6.9i/3.0i
mergefile="${work_dir}/many_series.merge"
regular="${work_dir}/regular.txt"
aggregate="${work_dir}/aggregate.txt"
ps_file="${work_dir}/ex08_many_series.ps"

make_series() {
	local file=$1 west=$2 east=$3 value=$4
	awk -v w="${west}" -v e="${east}" -v value="${value}" \
		'BEGIN {
			for (x = w; x <= e + 1e-9; x += 0.1)
				printf "%.1f %.12g\n", x, value
		}' > "${file}"
}

secondary="${work_dir}/secondary.txt"
p1="${work_dir}/p1.txt"
p2="${work_dir}/p2.txt"
p3="${work_dir}/p3.txt"
p4="${work_dir}/p4.txt"
p5="${work_dir}/p5.txt"
p6="${work_dir}/p6.txt"
p7="${work_dir}/p7.txt"

make_series "${secondary}" 0 100 1
make_series "${p1}" 70 95 8
make_series "${p2}" 65 75 7
make_series "${p3}" 55 100 6
make_series "${p4}" 15 35 5
make_series "${p5}" 37 53 4
make_series "${p6}" 5 20 3
make_series "${p7}" 0 45 2

cat > "${mergefile}" <<- EOF
	${p1} ${p3} - cosine 0.3/0.3
	${p2} ${p3} - cosine 0.3/0.3
	${p3} ${secondary} - cosine 0.3/0.3
	${p4} ${p7} - cosine 0.3/0.3
	${p5} ${secondary} - cosine 0.3/0.3
	${p6} ${p7} - cosine 0.3/0.3
	${p7} ${secondary} - cosine 0.3/0.3
	${secondary} - - - -
	EOF

gmt merge1d "${mergefile}" -T${range} -Fvalue -W -G"${regular}"
gmt merge1d "${mergefile}" -T${range} -Fvalue -W -A -G"${aggregate}"

# Both modes cover the full domain. Aggregation changes each overlap between
# peer primaries while keeping their shared secondary as a background layer.
paste "${regular}" "${aggregate}" | \
	awk '{
		x = $1
		if (tolower($2) == "nan" || tolower($5) == "nan") exit 1
		group = 0
		if (x >= 15 && x <= 20) group = 1
		else if (x >= 37 && x <= 45) group = 2
		else if (x >= 70 && x <= 75) group = 3
		if (group && ($2 - $5)^2 > 1e-8) changed[group] = 1
	}
	END {
		for (group = 1; group <= 3; group++)
			if (!changed[group]) {
				printf "No aggregate difference found in overlap group %d\n", \
				       group > "/dev/stderr"
				exit 1
			}
	}'

cat > "${work_dir}/supports.txt" <<- EOF
	>
	70 8
	95 8
	>
	65 7
	75 7
	>
	55 6
	100 6
	>
	15 5
	35 5
	>
	37 4
	53 4
	>
	5 3
	20 3
	>
	0 2
	45 2
	EOF
cat > "${work_dir}/primary_labels.txt" <<- EOF
	82.5 8.18 P1
	67.5 7.18 P2
	97.5 6.18 P3
	25 5.18 P4
	45 4.18 P5
	12.5 3.18 P6
	2.5 2.18 P7
	EOF
cat > "${work_dir}/overlaps.txt" <<- EOF
	15 0
	20 0
	20 8.8
	15 8.8
	>
	37 0
	45 0
	45 8.8
	37 8.8
	>
	70 0
	75 0
	75 8.8
	70 8.8
	EOF
cat > "${work_dir}/group_labels.txt" <<- EOF
	17.5 0.3 P4/P6 use P7
	41 0.3 P5/P7 use secondary
	72.5 0.3 P1/P2 use P3
	EOF
cat > "${work_dir}/legend_regular.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,gray40 0.28i Input series
	S 0.08i - 0.22i - 1.5p,black 0.28i Secondary
	S 0.08i - 0.22i - 1.5p,firebrick 0.28i Merged
	EOF
cat > "${work_dir}/legend_aggregate.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,gray40 0.28i Input series
	S 0.08i - 0.22i - 1.5p,black 0.28i Secondary
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i Merged
	EOF

gmt psbasemap -P -R${region} -J${projection} -Bxa10f5 \
	-Bya1f0.5+l"Value" -BWSen+t"(a) Without aggregate mode" \
	-X0.8i -Y6.7i -K > "${ps_file}"
gmt psxy "${work_dir}/overlaps.txt" -R -J -L \
	-Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/supports.txt" -R -J -W1.5p,gray40 -O -K >> "${ps_file}"
gmt psxy "${secondary}" -R -J -W1.5p,black -O -K >> "${ps_file}"
gmt psxy "${regular}" -i0,1 -R -J -W1.5p,firebrick -O -K >> "${ps_file}"
gmt pstext "${work_dir}/primary_labels.txt" -R -J \
	-F+f8p,Helvetica,black+jBC -O -K >> "${ps_file}"
gmt pstext "${work_dir}/group_labels.txt" -R -J \
	-F+f7p,Helvetica,gray25+jBC -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_regular.txt" -R -J -DjTC+o0/0.08i \
	-F+gwhite+p0.4p -O -K >> "${ps_file}"

gmt psbasemap -R${region} -J${projection} -Bxa10f5+l"Coordinate" \
	-Bya1f0.5+l"Value" -BWSen+t"(b) With aggregate mode (-A)" \
	-X0i -Y-4.0i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/overlaps.txt" -R -J -L \
	-Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/supports.txt" -R -J -W1.5p,gray40 -O -K >> "${ps_file}"
gmt psxy "${secondary}" -R -J -W1.5p,black -O -K >> "${ps_file}"
gmt psxy "${aggregate}" -i0,1 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pstext "${work_dir}/primary_labels.txt" -R -J \
	-F+f8p,Helvetica,black+jBC -O -K >> "${ps_file}"
gmt pstext "${work_dir}/group_labels.txt" -R -J \
	-F+f7p,Helvetica,gray25+jBC -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_aggregate.txt" -R -J -DjTC+o0/0.08i \
	-F+gwhite+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex08_many_series"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex08_many_series"
