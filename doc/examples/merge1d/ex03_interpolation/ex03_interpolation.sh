#!/usr/bin/env bash
#
# Compare the interpolation methods available in merge1d.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex03-interpolation.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

input="${script_dir}/irregular_series.txt"
range=0/10/0.05
region=0/10/1.5/7.7
projection=X3.15i/2.25i
ps_file="${work_dir}/ex03_interpolation.ps"

# Resample the irregular series using every interpolation method.
gmt merge1d "${input}" -T${range} -Sa -G"${work_dir}/akima.txt"
gmt merge1d "${input}" -T${range} -Sc -G"${work_dir}/cubic.txt"
gmt merge1d "${input}" -T${range} -Se -G"${work_dir}/step.txt"
gmt merge1d "${input}" -T${range} -Sl -G"${work_dir}/linear.txt"
gmt merge1d "${input}" -T${range} -Sn -G"${work_dir}/nearest.txt"
gmt merge1d "${input}" -T${range} -Ss0.5 -G"${work_dir}/smooth.txt"

# Linear interpolation is the default.
gmt merge1d "${input}" -T${range} -G"${work_dir}/default.txt"
cmp "${work_dir}/default.txt" "${work_dir}/linear.txt"

cat > "${work_dir}/legend_local.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i Linear (-Sl)
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i Nearest (-Sn)
	S 0.08i - 0.22i - 1.5p,orangered,. 0.28i Step-up (-Se)
	EOF
cat > "${work_dir}/legend_splines.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,deepskyblue 0.28i Akima (-Sa)
	S 0.08i - 0.22i - 1.5p,mediumorchid,- 0.28i Cubic (-Sc)
	EOF
cat > "${work_dir}/legend_smooth.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,mediumorchid,- 0.28i Cubic (-Sc)
	S 0.08i - 0.22i - 1.5p,orange 0.28i Smooth (-Ss0.5)
	EOF

# Panel (a): the original observations have irregular coordinate spacing.
gmt psbasemap -P -R${region} -J${projection} -Bxa2f1 -Bya1f0.5+l"Value" \
	-BWSen+t"(a) Irregular input" -X0.8i -Y5.2i -K > "${ps_file}"
gmt psxy "${input}" -R -J -Sc0.075i -Gblack -O -K >> "${ps_file}"

# Panel (b): local interpolation choices preserve sharp transitions.
gmt psbasemap -R${region} -J${projection} -Bxa2f1 -Bya1f0.5 \
	-BWSen+t"(b) Local methods" -X3.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/linear.txt" -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt psxy "${work_dir}/nearest.txt" -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/step.txt" -R -J -W1.5p,orangered,. -O -K >> "${ps_file}"
gmt psxy "${input}" -R -J -Sc0.055i -Gblack -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_local.txt" -R -J -DjBR+o0.08i \
	-F+gwhite+p0.4p -O -K >> "${ps_file}"

# Panel (c): Akima and cubic splines pass through the observations.
gmt psbasemap -R${region} -J${projection} -Bxa2f1+l"Coordinate" \
	-Bya1f0.5+l"Value" -BWSen+t"(c) Interpolating splines" \
	-X-3.75i -Y-3.0i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/akima.txt" -R -J -W1.5p,deepskyblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/cubic.txt" -R -J -W1.5p,mediumorchid,- -O -K >> "${ps_file}"
gmt psxy "${input}" -R -J -Sc0.055i -Gblack -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_splines.txt" -R -J -DjBR+o0.08i \
	-F+gwhite+p0.4p -O -K >> "${ps_file}"

# Panel (d): a smoothing spline need not pass through every observation.
gmt psbasemap -R${region} -J${projection} -Bxa2f1+l"Coordinate" \
	-Bya1f0.5 -BWSen+t"(d) Smoothing spline" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/cubic.txt" -R -J -W1.5p,mediumorchid,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/smooth.txt" -R -J -W1.5p,orange -O -K >> "${ps_file}"
gmt psxy "${input}" -R -J -Sc0.055i -Gblack -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_smooth.txt" -R -J -DjBR+o0.08i \
	-F+gwhite+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex03_interpolation"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex03_interpolation"
