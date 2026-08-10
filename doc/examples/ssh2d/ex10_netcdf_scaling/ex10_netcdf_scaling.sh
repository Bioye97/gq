#!/usr/bin/env bash
#
# Scale NetCDF axes and values before applying two-dimensional heterogeneity.

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
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex10.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

model_cdl="${work_dir}/model.cdl"
model_nc="${work_dir}/model.nc"
scaled_nc="${work_dir}/scaled.nc"
cat > "${model_cdl}" <<- EOF
	netcdf model {
	dimensions: x = 41 ; y = 31 ;
	variables:
		double x(x) ; x:axis = "X" ; x:units = "m" ;
		double y(y) ; y:axis = "Y" ; y:units = "m" ;
		float vp(y, x) ; vp:units = "m/s" ;
	data:
	EOF
awk 'BEGIN {
	printf "x = "; for(i=0;i<=40;i++) printf "%s%d",(i?", ":""),2500*i; print " ;";
	printf "y = "; for(i=0;i<=30;i++) printf "%s%d",(i?", ":""),2000*i; print " ;";
	printf "vp = "; for(j=0;j<=30;j++) for(i=0;i<=40;i++)
		printf "%s%.8g",(i||j?", ":""),5200+35*i+18*j; print " ;";
}' >> "${model_cdl}"
echo "}" >> "${model_cdl}"
"${ncgen_executable}" -o "${model_nc}" "${model_cdl}"

gmt ssh2d "${model_nc}+x0.001+Xkm+y0.001+Ykm+v0.001+Vkm/s" \
	-A -Fvp -D0.035 -C12/7 -U0.35 -Q91 -G"${scaled_nc}"
gmt makecpt -Cbatlow -T5000/7500/100 > "${work_dir}/source.cpt"
gmt makecpt -Cbatlow -T5/7.5/0.1 > "${work_dir}/scaled.cpt"

ps_file="${work_dir}/ex10_netcdf_scaling.ps"
gmt grdimage "${model_nc}?vp" -P -R0/100000/0/60000 -JX3.15i/2.3i \
	-C"${work_dir}/source.cpt" -Bxa20000f10000+l"X (m)" \
	-Bya20000f10000+l"Y (m)" -BWSen+t"(a) Source: m and m/s" \
	-X0.8i -Y2.0i -K > "${ps_file}"
gmt psscale -R -J -C"${work_dir}/source.cpt" \
	-DjBC+w2.3i/0.15i+h+o0/-1.0i -Bxa500+l"Velocity (m/s)" \
	--FONT_ANNOT_PRIMARY=16p --FONT_LABEL=16p -O -K >> "${ps_file}"
gmt grdimage "${scaled_nc}?vp" -R0/100/0/60 -JX3.15i/2.3i \
	-C"${work_dir}/scaled.cpt" -Bxa20f10+l"X (km)" -Bya20f10+l"Y (km)" \
	-BWSen+t"(b) Scaled and perturbed" -X3.75i -O -K >> "${ps_file}"
gmt psscale -R -J -C"${work_dir}/scaled.cpt" \
	-DjBC+w2.3i/0.15i+h+o0/-1.0i -Bxa0.5+l"Velocity (km/s)" \
	--FONT_ANNOT_PRIMARY=16p --FONT_LABEL=16p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex10_netcdf_scaling"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex10_netcdf_scaling"
