#!/usr/bin/env bash
#
# Map differently named NetCDF variables into one multiparameter output.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
ncdump_executable=${NCDUMP:-$(command -v ncdump || true)}
if [[ -z "${ncdump_executable}" ]]; then
	echo "ncdump was not found; set NCDUMP=/path/to/ncdump" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex05-netcdf.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

primary_text="${work_dir}/model1.txt"
secondary_text="${work_dir}/model2.txt"
primary_nc="${work_dir}/model1.nc"
secondary_nc="${work_dir}/model2.nc"
mergefile="${work_dir}/models.merge"
merged_nc="${work_dir}/merged.nc"
merged_text="${work_dir}/merged.txt"
weight_only_nc="${work_dir}/weight_only.nc"
projection=X3.15i/2.25i
ps_file="${work_dir}/ex05_multivariable_netcdf.ps"

# Model 1 uses vp, vs, and den; model 2 uses p, s, and d.
awk 'BEGIN {
	for (x = 10; x <= 90; x++)
		printf "%d %.12g %.12g %.12g\n", x, \
		       6.0 + 0.3 * sin(x / 12.0), \
		       3.5 + 0.2 * sin(x / 10.0), \
		       2.7 + 0.05 * cos(x / 15.0)
}' > "${primary_text}"
awk 'BEGIN {
	for (x = 0; x <= 100; x++)
		printf "%d %.12g %.12g %.12g\n", x, \
		       5.0 + 0.2 * cos(x / 14.0), \
		       2.8 + 0.15 * cos(x / 11.0), \
		       2.4 + 0.03 * sin(x / 13.0)
}' > "${secondary_text}"

# Package the text columns as named variables in two NetCDF files.
gmt merge1d "${primary_text}" -T10/90/1 -Fvp,vs,den -G"${primary_nc}"
gmt merge1d "${secondary_text}" -T0/100/1 -Fp,s,d -G"${secondary_nc}"

# Source variables map positionally to the final names supplied by -F.
cat > "${mergefile}" <<- EOF
	${primary_nc}?vp,vs,den ${secondary_nc}?p,s,d 20/80 cosine 0.2/0.3
	${secondary_nc}?p,s,d - - - -
	EOF
gmt merge1d "${mergefile}" -T0/100/1 -Fvp,vs,rho -W -G"${merged_nc}"
gmt merge1d "${mergefile}" -T0/100/1 -Fvp,vs,rho -W -G"${merged_text}"
gmt merge1d "${mergefile}" -T0/100/1 -W+o -G"${weight_only_nc}"

# Confirm the selected output names and fixed weight metadata.
"${ncdump_executable}" -h "${merged_nc}" > "${work_dir}/merged.header"
for variable in vp vs rho weight; do
	grep -Eq "(float|double) ${variable}\\(" "${work_dir}/merged.header"
done
grep -q 'weight:long_name = "merging weight"' "${work_dir}/merged.header"
grep -q 'weight:units = "1"' "${work_dir}/merged.header"
"${ncdump_executable}" -h "${weight_only_nc}" > "${work_dir}/weight_only.header"
grep -Eq '(float|double) weight\(' "${work_dir}/weight_only.header"
if grep -Eq '(float|double) (vp|vs|rho)\(' "${work_dir}/weight_only.header"; then
	echo "-W+o unexpectedly wrote model variables" >&2
	exit 1
fi

cat > "${work_dir}/legend_vp.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i model1: vp
	S 0.08i - 0.22i - 1.5p,orangered,- 0.28i model2: p
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i output: vp
	EOF
cat > "${work_dir}/legend_vs.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i model1: vs
	S 0.08i - 0.22i - 1.5p,orangered,- 0.28i model2: s
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i output: vs
	EOF
cat > "${work_dir}/legend_rho.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i model1: den
	S 0.08i - 0.22i - 1.5p,orangered,- 0.28i model2: d
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i output: rho
	EOF
cat > "${work_dir}/legend_weight.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,deepskyblue 0.28i Merging weight
	EOF

# Panel (a): vp and p map to output variable vp.
gmt psbasemap -P -R0/100/4.6/6.5 -J${projection} -Bxa20f10 \
	-Bya0.5f0.25+l"V@-P@-" -BWSen+t"(a) Compressional wave speed" \
	-X0.8i -Y5.2i -K > "${ps_file}"
printf "20 4.6\n80 4.6\n80 6.5\n20 6.5\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary_text}" -i0,1 -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${secondary_text}" -i0,1 -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${merged_text}" -i0,1 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_vp.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (b): vs and s map to output variable vs.
gmt psbasemap -R0/100/2.5/3.8 -J${projection} -Bxa20f10 \
	-Bya0.2f0.1+l"V@-S@-" -BWSen+t"(b) Shear wave speed" \
	-X3.75i -O -K >> "${ps_file}"
printf "20 2.5\n80 2.5\n80 3.8\n20 3.8\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary_text}" -i0,2 -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${secondary_text}" -i0,2 -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${merged_text}" -i0,2 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_vs.txt" -R -J -DJBC+o0/0.30i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (c): den and d map to output variable rho.
gmt psbasemap -R0/100/2.3/2.8 -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya0.1f0.05+l"Density" -BWSen+t"(c) Density" \
	-X-3.75i -Y-3.8i -O -K >> "${ps_file}"
printf "20 2.3\n80 2.3\n80 2.8\n20 2.8\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${primary_text}" -i0,3 -R -J -W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${secondary_text}" -i0,3 -R -J -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${merged_text}" -i0,3 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_rho.txt" -R -J -DJBC+o0/0.5i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (d): all fields share the same asymmetric cosine taper.
gmt psbasemap -R0/100/-0.05/1.05 -J${projection} \
	-Bxa20f10+l"Coordinate" -Bya0.2f0.1+l"Weight" \
	-BWSen+t"(d) Shared merging weight" \
	-X3.75i -O -K >> "${ps_file}"
printf "20 -0.05\n32 -0.05\n32 1.05\n20 1.05\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
printf "62 -0.05\n80 -0.05\n80 1.05\n62 1.05\n" | \
	gmt psxy -R -J -Ggray94 -W0.4p,gray75,- -O -K >> "${ps_file}"
gmt psxy "${merged_text}" -i0,4 -R -J -W1.5p,deepskyblue -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_weight.txt" -R -J -DJBC+o0/0.5i \
	-F+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex05_multivariable_netcdf"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex05_multivariable_netcdf"
