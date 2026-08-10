#!/usr/bin/env bash
#
# Blend a primary series into a secondary series using a cosine taper.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex02-blending.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

primary="${work_dir}/primary.txt"
secondary="${work_dir}/secondary.txt"
mergefile="${work_dir}/blend.merge"
merged="${work_dir}/merged.txt"
components="${work_dir}/components.txt"
profile_region=0/100/0/11
weight_region=0/100/-0.05/1.05
projection=X3.15i/2.25i
ps_file="${work_dir}/ex02_blending.ps"

# Generate two smooth input series on the same coordinate axis.
gmt math -T10/90/1 T 12 DIV SIN 0.8 MUL T 0.02 MUL ADD 7 ADD = "${primary}"
gmt math -T0/100/1 T 15 DIV COS 0.4 MUL T 0.01 MUL ADD 2 ADD = "${secondary}"

# Blend the primary into the secondary over the support interval 20/80.
cat > "${mergefile}" <<- EOF
	${primary} ${secondary} 20/80 cosine 0.25/0.25
	${secondary} - - - -
	EOF
gmt merge1d "${mergefile}" -T0/100/1 -W -G"${merged}"

# Separate the primary and secondary contributions to the merged result.
awk 'FILENAME == ARGV[1] {primary[$1] = $2; next}
	 FILENAME == ARGV[2] {secondary[$1] = $2; next}
	 {
	     p = ($1 in primary) ? primary[$1] : 0
	     s = ($1 in secondary) ? secondary[$1] : 0
	     printf "%.12g %.12g %.12g %.12g\n", \
	            $1, p * $3, s * (1 - $3), $2
	 }' "${primary}" "${secondary}" "${merged}" > "${components}"
awk '{if ($3 < 0 || $3 > 1) exit 1}' "${merged}"
awk '{if (($2 + $3 - $4)^2 > 1e-12) exit 1}' "${components}"

cat > "${work_dir}/legend_inputs.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Primary
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Secondary
	EOF
cat > "${work_dir}/legend_weight.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,deepskyblue 0.28i Merging weight
	EOF
cat > "${work_dir}/legend_merged.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i Primary
	S 0.08i - 0.22i - 3.0p,orangered,- 0.28i Secondary
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i Merged
	EOF
cat > "${work_dir}/legend_components.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Primary contribution
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Secondary contribution
	S 0.08i - 0.22i - 1.5p,seagreen,- 0.28i Sum
	EOF

# Panel (a): primary and secondary input series.
gmt psbasemap -P -R${profile_region} -J${projection} -Bxa20f10 \
	-Bya2f1+l"Value" -BWSen+t"(a) Input series" \
	-X0.8i -Y5.2i -K > "${ps_file}"
printf "20 0\n80 0\n80 11\n20 11\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary}" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${secondary}" -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_inputs.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"
echo "50 0.45 Primary support" | \
	gmt pstext -R -J -F+f8p,Helvetica,gray35+jBC -O -K >> "${ps_file}"

# Panel (b): cosine merging weight over the support.
gmt psbasemap -R${weight_region} -J${projection} -Bxa20f10 \
	-Bya0.2f0.1+l"Weight" -BWSen+t"(b) Cosine taper" \
	-X3.75i -O -K >> "${ps_file}"
printf "20 -0.05\n35 -0.05\n35 1.05\n20 1.05\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
printf "65 -0.05\n80 -0.05\n80 1.05\n65 1.05\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${merged}" -i0,2 -R -J -W1.5p,deepskyblue \
	-O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_weight.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (c): the merged series follows the secondary outside the support.
gmt psbasemap -R${profile_region} -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya2f1+l"Value" -BWSen+t"(c) Merged series" \
	-X-3.75i -Y-3.8i -O -K >> "${ps_file}"
printf "20 0\n80 0\n80 11\n20 11\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary}" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${secondary}" -R -J -W3.0p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${merged}" -i0,1 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_merged.txt" -R -J -DJBC+o0/0.5i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (d): weighted contributions add to the merged series.
gmt psbasemap -R${profile_region} -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya2f1 -BWSen+t"(d) Weighted contributions" \
	-X3.75i -O -K >> "${ps_file}"
printf "20 0\n80 0\n80 11\n20 11\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${components}" -i0,1 -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${components}" -i0,2 -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${components}" -i0,3 -R -J -W1.5p,seagreen,- -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_components.txt" -R -J -DJBC+o0/0.5i \
	-F+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex02_blending"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex02_blending"
