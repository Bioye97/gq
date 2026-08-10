#!/usr/bin/env bash
#
# Compare merge1d clobber modes.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex01-clobber.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

series_a="${script_dir}/series_a.txt"
series_b="${script_dir}/series_b.txt"
range=0/14/1
region=0/14/-8/9
projection=X3.15i/2.25i
ps_file="${work_dir}/ex01_clobber.ps"

# Direct file lists use first-value clobbering by default.
gmt merge1d "${series_a}" "${series_b}" -T${range} \
	-G"${work_dir}/default.txt"
gmt merge1d "${series_a}" "${series_b}" -T${range} -Cf \
	-G"${work_dir}/first.txt"
cmp "${work_dir}/default.txt" "${work_dir}/first.txt"

# Compare all clobber choices and both value restrictions.
gmt merge1d "${series_a}" "${series_b}" -T${range} -Co \
	-G"${work_dir}/last.txt"
gmt merge1d "${series_a}" "${series_b}" -T${range} -Cl \
	-G"${work_dir}/lower.txt"
gmt merge1d "${series_a}" "${series_b}" -T${range} -Cu \
	-G"${work_dir}/upper.txt"
gmt merge1d "${series_a}" "${series_b}" -T${range} -Co+n \
	-G"${work_dir}/last_nonpositive.txt"
gmt merge1d "${series_a}" "${series_b}" -T${range} -Co+p \
	-G"${work_dir}/last_nonnegative.txt"

cat > "${work_dir}/legend_inputs.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Series A
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Series B
	EOF
cat > "${work_dir}/legend_precedence.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,hotpink 0.28i Default / -Cf (first)
	S 0.08i - 0.22i - 1.5p,mediumorchid,- 0.28i -Co (last)
	EOF
cat > "${work_dir}/legend_extrema.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i -Cl (lowest)
	S 0.08i - 0.22i - 1.5p,orange,- 0.28i -Cu (highest)
	EOF
cat > "${work_dir}/legend_restricted.txt" <<- EOF
	S 0.08i - 0.22i - 4.0p,mediumorchid 0.28i -Co (last)
	S 0.08i - 0.22i - 1.5p,deepskyblue 0.28i Non-positive only (last)
	S 0.08i - 0.22i - 1.5p,black,- 0.28i Non-negative only (last)
	EOF

# Panel (a): inputs and their overlap.
gmt psbasemap -P -R${region} -J${projection} -Bxa2f1 -Bya4f2+l"Value" \
	-BWSen+t"(a) Input series" -X0.8i -Y5.2i -K > "${ps_file}"
printf "4 -8\n10 -8\n10 9\n4 9\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${series_a}" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${series_a}" -R -J -Sc0.075i -Groyalblue -O -K >> "${ps_file}"
gmt psxy "${series_b}" -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${series_b}" -R -J -Sc0.075i -Gorangered -O -K >> "${ps_file}"
echo "7 -7.1 Overlap" | \
	gmt pstext -R -J -F+f8p,Helvetica,gray35+jBC -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_inputs.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (b): input order controls first and last clobbering.
gmt psbasemap -R${region} -J${projection} -Bxa2f1 -Bya4f2 \
	-BWSen+t"(b) First and last" -X3.75i -O -K >> "${ps_file}"
printf "4 -8\n10 -8\n10 9\n4 9\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/first.txt" -R -J -W1.5p,hotpink \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/last.txt" -R -J -W1.5p,mediumorchid,- \
	-O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_precedence.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (c): data values control lower and upper clobbering.
gmt psbasemap -R${region} -J${projection} -Bxa2f1+l"Coordinate" \
	-Bya4f2+l"Value" -BWSen+t"(c) Extrema values" \
	-X-3.75i -Y-3.8i -O -K >> "${ps_file}"
printf "4 -8\n10 -8\n10 9\n4 9\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/lower.txt" -R -J -W1.5p,seagreen \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/upper.txt" -R -J -W1.5p,orange,- \
	-O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_extrema.txt" -R -J -DJBC+o0/0.5i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (d): sign modifiers filter replacements, not initial values.
gmt psbasemap -R${region} -J${projection} -Bxa2f1+l"Coordinate" \
	-Bya4f2 -BWSen+t"(d) Restricted tiling (last)" \
	-X3.75i -O -K >> "${ps_file}"
printf "4 -8\n10 -8\n10 9\n4 9\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/last.txt" -R -J -W4.0p,mediumorchid \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/last_nonpositive.txt" -R -J -W1.5p,deepskyblue \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/last_nonnegative.txt" -R -J -W1.5p,black,- \
	-O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_restricted.txt" -R -J -DJBC+o0/0.5i \
	-F+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex01_clobber"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex01_clobber"
