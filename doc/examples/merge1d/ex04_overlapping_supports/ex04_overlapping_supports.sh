#!/usr/bin/env bash
#
# Normalize the weights of overlapping primary supports with merge1d -A.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex04-overlap.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p PS_MEDIA legal

primary1="${work_dir}/primary1.txt"
primary2="${work_dir}/primary2.txt"
secondary="${work_dir}/secondary.txt"
mergefile="${work_dir}/overlap.merge"
regular="${work_dir}/regular.txt"
merged="${work_dir}/merged.txt"
weights="${work_dir}/weights.txt"
components="${work_dir}/components.txt"
profile_region=0/100/1/11
weight_region=0/100/-0.05/2.05
contribution_region=0/100/-0.05/1.05
projection=X3.15i/2.25i
ps_file="${work_dir}/ex04_overlapping_supports.ps"

# Generate two overlapping primary series and their shared secondary.
gmt math -T10/65/1 T 8 DIV SIN 0.5 MUL 7 ADD = "${primary1}"
gmt math -T35/90/1 T 9 DIV COS 0.5 MUL 10 ADD = "${primary2}"
gmt math -T0/100/1 T 25 DIV SIN 0.3 MUL 2 ADD = "${secondary}"

# Obtain each support weight separately for comparison with the normalized run.
cat > "${work_dir}/primary1.merge" <<- EOF
	${primary1} ${secondary} 10/65 cosine 0.25/0.25
	EOF
cat > "${work_dir}/primary2.merge" <<- EOF
	${primary2} ${secondary} 35/90 cosine 0.25/0.25
	EOF
gmt merge1d "${work_dir}/primary1.merge" -T0/100/1 -W+o \
	-G"${work_dir}/weight1.txt"
gmt merge1d "${work_dir}/primary2.merge" -T0/100/1 -W+o \
	-G"${work_dir}/weight2.txt"

# The last record tiles the shared secondary beyond both primary domains.
cat > "${mergefile}" <<- EOF
	${primary1} ${secondary} 10/65 cosine 0.25/0.25
	${primary2} ${secondary} 35/90 cosine 0.25/0.25
	${secondary} - - - -
	EOF
gmt merge1d "${mergefile}" -T0/100/1 -G"${regular}"
gmt merge1d "${mergefile}" -T0/100/1 -A -W -G"${merged}"

# Confirm that aggregate merging changes the result inside the overlap.
awk 'FILENAME == ARGV[1] {regular[$1] = $2; next}
	 $1 >= 35 && $1 <= 65 && ($2 - regular[$1])^2 > 1e-8 {different = 1}
	 END {exit !different}' "${regular}" "${merged}"

# Compute the normalized primary and background contributions for plotting.
awk 'FILENAME == ARGV[1] {w2[$1] = $2; next}
	 {
	     sum = $2 + w2[$1]
	     background = (sum < 1) ? 1 - sum : 0
	     total = sum + background
	     printf "%.12g %.12g %.12g %.12g %.12g %.12g %.12g\n", \
	            $1, $2, w2[$1], sum, $2 / total, w2[$1] / total, \
	            background / total
	 }' "${work_dir}/weight2.txt" "${work_dir}/weight1.txt" > "${weights}"

# Reconstruct the aggregate result from the three normalized contributions.
awk 'FILENAME == ARGV[1] {p1[$1] = $2; next}
	 FILENAME == ARGV[2] {p2[$1] = $2; next}
	 FILENAME == ARGV[3] {s[$1] = $2; next}
	 FILENAME == ARGV[4] {m[$1] = $2; next}
	 {
	     a = ($1 in p1) ? p1[$1] : 0
	     b = ($1 in p2) ? p2[$1] : 0
	     expected = $5 * a + $6 * b + $7 * s[$1]
	     printf "%.12g %.12g %.12g %.12g %.12g %.12g\n", \
	            $1, $5 * a, $6 * b, $7 * s[$1], expected, m[$1]
	     if ((expected - m[$1])^2 > 1e-18) exit 1
	     if (($5 + $6 + $7 - 1)^2 > 1e-18) exit 1
	 }' "${primary1}" "${primary2}" "${secondary}" "${merged}" \
	"${weights}" > "${components}"

cat > "${work_dir}/legend_inputs.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Primary 1
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Primary 2
	S 0.08i - 0.22i - 1.5p,gray40,- 0.28i Secondary
	EOF
cat > "${work_dir}/legend_weights.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Primary 1
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Primary 2
	S 0.08i - 0.22i - 1.5p,black,- 0.28i Sum
	EOF
cat > "${work_dir}/legend_contributions.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Primary 1
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Primary 2
	S 0.08i - 0.22i - 1.5p,gray40,- 0.28i Secondary
	EOF
cat > "${work_dir}/legend_merged.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i Primary 1
	S 0.08i - 0.22i - 1.5p,orangered,- 0.28i Primary 2
	S 0.08i - 0.22i - 1.5p,gray40,- 0.28i Secondary
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i Merged
	EOF
cat > "${work_dir}/legend_regular.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i Primary 1
	S 0.08i - 0.22i - 1.5p,orangered,- 0.28i Primary 2
	S 0.08i - 0.22i - 1.5p,gray40,- 0.28i Secondary
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i Merged
	EOF

# Panel (a): the primary domains overlap between coordinates 35 and 65.
gmt psbasemap -P -R${profile_region} -J${projection} -Bxa20f10 \
	-Bya2f1+l"Value" -BWSen+t"(a) Input series" \
	-X0.8i -Y11.0i -K > "${ps_file}"
printf "35 1\n65 1\n65 11\n35 11\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary1}" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${primary2}" -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${secondary}" -R -J -W1.5p,gray40,- -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_inputs.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"
echo "50 1.45 Overlap" | \
	gmt pstext -R -J -F+f8p,Helvetica,gray35+jBC -O -K >> "${ps_file}"

# Panel (b): raw taper weights exceed one when both primaries contribute.
gmt psbasemap -R${weight_region} -J${projection} -Bxa20f10 \
	-Bya0.5f0.25+l"Weight" -BWSen+t"(b) Raw support weights" \
	-X3.75i -O -K >> "${ps_file}"
printf "35 -0.05\n65 -0.05\n65 2.05\n35 2.05\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${weights}" -i0,1 -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${weights}" -i0,2 -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${weights}" -i0,3 -R -J -W1.5p,black,- -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_weights.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (c): normalized contributions sum to one across the full axis.
gmt psbasemap -R${contribution_region} -J${projection} \
	-Bxa20f10 -Bya0.2f0.1+l"Contribution" \
	-BWSen+t"(c) Normalized contributions" \
	-X-3.75i -Y-3.8i -O -K >> "${ps_file}"
printf "35 -0.05\n65 -0.05\n65 1.05\n35 1.05\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${weights}" -i0,4 -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${weights}" -i0,5 -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${weights}" -i0,6 -R -J -W1.5p,gray40,- -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_contributions.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (d): regular merging retains the first available primary record.
gmt psbasemap -R${profile_region} -J${projection} -Bxa20f10 \
	-Bya2f1 -BWSen+t"(d) Regular merge" \
	-X3.75i -O -K >> "${ps_file}"
printf "35 1\n65 1\n65 11\n35 11\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary1}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${primary2}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${secondary}" -R -J -W1.5p,gray40,- -O -K >> "${ps_file}"
gmt psxy "${regular}" -i0,1 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_regular.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (e): aggregate merging transitions between both primaries.
gmt psbasemap -R${profile_region} -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya2f1+l"Value" -BWSen+t"(e) Aggregate merge (-A)" \
	-X-1.875i -Y-3.8i -O -K >> "${ps_file}"
printf "35 1\n65 1\n65 11\n35 11\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary1}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${primary2}" -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${secondary}" -R -J -W1.5p,gray40,- -O -K >> "${ps_file}"
gmt psxy "${merged}" -i0,1 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_merged.txt" -R -J -DJBC+o0/0.5i \
	-F+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex04_overlapping_supports"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex04_overlapping_supports"
