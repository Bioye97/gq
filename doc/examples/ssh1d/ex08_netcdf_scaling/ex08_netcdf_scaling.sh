#!/usr/bin/env bash
#
# Scale NetCDF coordinates and parameters before applying heterogeneity.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
ncgen_executable=${NCGEN:-$(command -v ncgen || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
if [[ -z "${ncgen_executable}" ]]; then
	echo "ncgen was not found; set NCGEN=/path/to/ncgen" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex08.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

model_cdl="${work_dir}/model.cdl"
model_nc="${work_dir}/model.nc"
scaled_nc="${work_dir}/scaled.nc"

cat > "${model_cdl}" <<- EOF
	netcdf model {
	dimensions:
		x = 101 ;
	variables:
		double x(x) ;
			x:axis = "X" ;
			x:units = "m" ;
		float vp(x) ;
			vp:units = "m/s" ;
		float vs(x) ;
			vs:units = "m/s" ;
	data:
	EOF
awk 'BEGIN {
	printf "x = ";
	for (i = 0; i <= 100; i++) printf "%s%d", (i ? ", " : ""), i * 1000;
	print " ;";
	printf "vp = ";
	for (i = 0; i <= 100; i++) printf "%s%.8g", (i ? ", " : ""), 5600 + 12 * i;
	print " ;";
	printf "vs = ";
	for (i = 0; i <= 100; i++) printf "%s%.8g", (i ? ", " : ""), 3200 + 7 * i;
	print " ;";
}' >> "${model_cdl}"
echo "}" >> "${model_cdl}"
"${ncgen_executable}" -o "${model_nc}" "${model_cdl}"

# Convert m to km and m/s to km/s before defining the correlation length.
gmt ssh1d "${model_nc}+x0.001+Xkm+v0.001+Vkm/s" -A -Fvp,vs \
	-D0.035 -C10 -U0.35 -Q91 -G"${scaled_nc}"

gmt convert "${model_nc}?x,vp,vs" > "${work_dir}/source.txt"
gmt convert "${scaled_nc}?x,vp,vs" > "${work_dir}/scaled.txt"

cat > "${work_dir}/legend.legend" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Vp
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Vs
	EOF

ps_file="${work_dir}/ex08_netcdf_scaling.ps"

gmt psbasemap -P -R0/100000/2500/7500 -JX3.15i/2.7i \
	-Bxa20000f10000+l"Coordinate (m)" -Bya1000f500+l"Velocity (m/s)" \
	-BWSen+t"(a) Source NetCDF units" -X0.8i -Y1.8i -K > "${ps_file}"
gmt psxy "${work_dir}/source.txt" -i0,1 -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/source.txt" -i0,2 -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend.legend" -R -J -DjTL+o0.08i \
	-F+p0.4p -O -K >> "${ps_file}"

gmt psbasemap -R0/100/2.5/7.5 -JX3.15i/2.7i \
	-Bxa20f10+l"Coordinate (km)" -Bya1f0.5+l"Velocity (km/s)" \
	-BWSen+t"(b) Scaled and perturbed" -X3.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/scaled.txt" -i0,1 -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/scaled.txt" -i0,2 -R -J -W1.5p,orangered -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex08_netcdf_scaling"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex08_netcdf_scaling"
