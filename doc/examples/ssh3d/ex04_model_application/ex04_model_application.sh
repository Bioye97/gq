#!/usr/bin/env bash
#
# Scale and perturb a multiparameter three-dimensional NetCDF model.

set -euo pipefail
gmt_executable=${GMT:-$(command -v gmt || true)}
ncgen_executable=${NCGEN:-$(command -v ncgen || true)}
[[ -n "${gmt_executable}" ]] || { echo "GMT was not found; set GMT=/path/to/gmt" >&2; exit 1; }
[[ -n "${ncgen_executable}" ]] || { echo "ncgen was not found; set NCGEN=/path/to/ncgen" >&2; exit 1; }
gmt() { command "${gmt_executable}" "$@"; }
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh3d-ex04.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"
gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

cdl="${work_dir}/model.cdl"; model="${work_dir}/model.nc"; output="${work_dir}/perturbed.nc"
cat > "${cdl}" <<- EOF
	netcdf model {
	dimensions: x=21; y=21; z=21;
	variables:
		double x(x); x:axis="X"; x:units="m";
		double y(y); y:axis="Y"; y:units="m";
		double z(z); z:axis="Z"; z:units="m";
		float vp(z,y,x); vp:units="m/s";
		float vs(z,y,x); vs:units="m/s";
	data:
	EOF
awk 'BEGIN {
	printf "x = "; for(i=0;i<21;i++) printf "%s%d",(i?", ":""),i*1000; print " ;";
	printf "y = "; for(i=0;i<21;i++) printf "%s%d",(i?", ":""),i*1000; print " ;";
	printf "z = "; for(i=0;i<21;i++) printf "%s%d",(i?", ":""),i*1000; print " ;";
	printf "vp = "; for(k=0;k<21;k++) for(j=0;j<21;j++) for(i=0;i<21;i++) printf "%s%.8g",(i||j||k?", ":""),5400+35*i+12*j+18*k; print " ;";
	printf "vs = "; for(k=0;k<21;k++) for(j=0;j<21;j++) for(i=0;i<21;i++) printf "%s%.8g",(i||j||k?", ":""),3100+18*i+7*j+10*k; print " ;";
}' >> "${cdl}"
echo "}" >> "${cdl}"
"${ncgen_executable}" -o "${model}" "${cdl}"

gmt ssh3d "${model}+x0.001+Xkm+y0.001+Ykm+z0.001+Zkm+v0.001+Vkm/s" \
	-A -Fvp,vs -D0.04 -C4/3/2 -U0.35 -Dvp/0.025 -Dvs/0.05 \
	-Cvp/5/4/3 -Cvs/3/2/1.5 -Q73+i -G"${output}"
for field in vp vs; do
	gmt grdconvert "${model}?${field}[10]" "${work_dir}/${field}_original_horizontal_raw.nc"
	gmt grdmath "${work_dir}/${field}_original_horizontal_raw.nc" 0.001 MUL \
		= "${work_dir}/${field}_original_horizontal.nc"
	gmt grdedit "${work_dir}/${field}_original_horizontal.nc" -R0/20/0/20
	gmt grdcut "${model}?${field}" -Ey10000 \
		-G"${work_dir}/${field}_original_vertical_raw.nc"
	gmt grdmath "${work_dir}/${field}_original_vertical_raw.nc" 0.001 MUL \
		= "${work_dir}/${field}_original_vertical.nc"
	gmt grdedit "${work_dir}/${field}_original_vertical.nc" -R0/20/0/20
	gmt grdconvert "${output}?${field}[10]" "${work_dir}/${field}_horizontal.nc"
	gmt grdcut "${output}?${field}" -Ey10 -G"${work_dir}/${field}_vertical.nc"
done
gmt makecpt -Cbatlow -T5/7.5/0.1 > "${work_dir}/vp.cpt"
gmt makecpt -Cbatlow -T3/4.5/0.05 > "${work_dir}/vs.cpt"

plot_field() {
	local field=$1 label=$2
	local ps_file="${work_dir}/ex04_model_application_${field}.ps"
	local states=(original perturbed original perturbed)
	local views=(horizontal horizontal vertical vertical)
	local sections=("z = 10 km" "z = 10 km" "y = 10 km" "y = 10 km")
	local letters=(a b c d)
	local state_name grid ylabel shift

	for ((i=0; i<4; i++)); do
		shift=()
		((i==0)) && shift=(-X0.8i -Y5.2i)
		((i==1 || i==3)) && shift=(-X3.75i)
		((i==2)) && shift=(-X-3.75i -Y-4.0i)
		state_name=Perturbed
		grid="${work_dir}/${field}_${views[i]}.nc"
		if [[ ${states[i]} == original ]]; then
			state_name=Original
			grid="${work_dir}/${field}_original_${views[i]}.nc"
		fi
		ylabel=Y
		[[ ${views[i]} == vertical ]] && ylabel=Z
		if ((i==0)); then
			gmt grdimage "${grid}" -P -R0/20/0/20 -JX3.15i \
				-C"${work_dir}/${field}.cpt" -Bxa5f2.5+l"X (km)" \
				-Bya5f2.5+l"${ylabel} (km)" \
				-BWSen+t"(${letters[i]}) ${label} ${state_name}: ${sections[i]}" \
				"${shift[@]}" -K > "${ps_file}"
		else
			gmt grdimage "${grid}" -R0/20/0/20 -JX3.15i \
				-C"${work_dir}/${field}.cpt" -Bxa5f2.5+l"X (km)" \
				-Bya5f2.5+l"${ylabel} (km)" \
				-BWSen+t"(${letters[i]}) ${label} ${state_name}: ${sections[i]}" \
				"${shift[@]}" -O -K >> "${ps_file}"
		fi
	done
	gmt psscale -R -J -C"${work_dir}/${field}.cpt" \
		-DjBC+w4.8i/0.15i+h+o-1.875i/-1.0i \
		-Bxa0.5+l"${label} (km/s)" \
		--FONT_ANNOT_PRIMARY=11p --FONT_LABEL=11p -O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A -Tf \
		-F"${script_dir}/ex04_model_application_${field}"
	gmt psconvert "${ps_file}" -A -Tg -E300 \
		-F"${script_dir}/ex04_model_application_${field}"
}

plot_field vp Vp
plot_field vs Vs
