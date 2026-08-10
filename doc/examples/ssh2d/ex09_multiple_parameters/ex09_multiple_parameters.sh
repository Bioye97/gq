#!/usr/bin/env bash
#
# Apply independent field-specific heterogeneities to a multiparameter grid.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex09.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

model_cdl="${work_dir}/model.cdl"
model_nc="${work_dir}/model.nc"
perturbed="${work_dir}/perturbed.nc"
cat > "${model_cdl}" <<- EOF
	netcdf model {
	dimensions: x = 51 ; y = 51 ;
	variables:
		double x(x) ; x:axis = "X" ;
		double y(y) ; y:axis = "Y" ;
		float vp(y, x) ; vp:units = "km/s" ;
		float vs(y, x) ; vs:units = "km/s" ;
		float rho(y, x) ; rho:units = "g/cm3" ;
	data:
	EOF
awk 'BEGIN {
	printf "x = "; for (i=0;i<=50;i++) printf "%s%d",(i?", ":""),2*i; print " ;";
	printf "y = "; for (i=0;i<=50;i++) printf "%s%d",(i?", ":""),2*i; print " ;";
	printf "vp = "; for (j=0;j<=50;j++) for (i=0;i<=50;i++)
		printf "%s%.8g",(i||j?", ":""),5.7+0.018*i+0.008*j; print " ;";
	printf "vs = "; for (j=0;j<=50;j++) for (i=0;i<=50;i++)
		printf "%s%.8g",(i||j?", ":""),3.2+0.010*i+0.004*j; print " ;";
	printf "rho = "; for (j=0;j<=50;j++) for (i=0;i<=50;i++)
		printf "%s%.8g",(i||j?", ":""),2.55+0.003*i+0.001*j; print " ;";
}' >> "${model_cdl}"
echo "}" >> "${model_cdl}"
"${ncgen_executable}" -o "${model_nc}" "${model_cdl}"

gmt ssh2d "${model_nc}" -A -Fvp,vs,rho -D0.04 -C8 -U0.4 \
	-Dvp/0.025 -Dvs/0.05 -Drho/0.015 \
	-Cvp/12/8 -Cvs/7/4 -Crho/4/3 -Q73+i -G"${perturbed}"
for field in vp vs rho; do
	gmt grdmath "${perturbed}?${field}" "${model_nc}?${field}" DIV \
		1 SUB 100 MUL = "${work_dir}/${field}_percent.nc"
done
gmt makecpt -Cvik -T-15/15/1 > "${work_dir}/percent.cpt"

fields=(vp vs rho)
titles=("Vp: sigma 2.5%" "Vs: sigma 5%" "Density: sigma 1.5%")
letters=(a b c)
ps_file="${work_dir}/ex09_multiple_parameters.ps"
projection=X2.0i
for ((index=0; index<3; index++)); do
	shift=(-X2.55i)
	if ((index==0)); then shift=(-X0.6i -Y2.0i); fi
	yaxis=-Bya20f10
	if ((index==0)); then yaxis=-Bya20f10+lY; fi
	if ((index==0)); then
		gmt grdimage "${work_dir}/${fields[index]}_percent.nc" -P \
			-R0/100/0/100 -J${projection} -C"${work_dir}/percent.cpt" \
			-Bxa20f10+lX "${yaxis}" -BWSen+t"(${letters[index]}) ${titles[index]}" \
			"${shift[@]}" -K > "${ps_file}"
	else
		gmt grdimage "${work_dir}/${fields[index]}_percent.nc" \
			-R0/100/0/100 -J${projection} -C"${work_dir}/percent.cpt" \
			-Bxa20f10+lX "${yaxis}" -BWSen+t"(${letters[index]}) ${titles[index]}" \
			"${shift[@]}" -O -K >> "${ps_file}"
	fi
done
gmt psscale -R -J -C"${work_dir}/percent.cpt" \
	-DjBC+w4.2i/0.15i+h+o-2.55i/-1.0i -Bxa5+l"Perturbation (%)" \
	--FONT_ANNOT_PRIMARY=12p --FONT_LABEL=12p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex09_multiple_parameters"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex09_multiple_parameters"
