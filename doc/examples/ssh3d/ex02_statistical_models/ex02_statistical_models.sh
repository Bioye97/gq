#!/usr/bin/env bash
#
# Compare all four ssh3d statistical models at a common depth.

set -euo pipefail
gmt_executable=${GMT:-$(command -v gmt || true)}
[[ -n "${gmt_executable}" ]] || { echo "GMT was not found; set GMT=/path/to/gmt" >&2; exit 1; }
gmt() { command "${gmt_executable}" "$@"; }
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh3d-ex02.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"
gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

gmt ssh3d -R0/80/0/80 -I1 -T0/40/1 -D0.05 -C7 -U0.35 -Mv -Q24 -G"${work_dir}/von_karman.nc"
gmt ssh3d -R0/80/0/80 -I1 -T0/40/1 -D0.05 -C7 -Mg -Q24 -G"${work_dir}/gaussian.nc"
gmt ssh3d -R0/80/0/80 -I1 -T0/40/1 -D0.05 -C7 -Me -Q24 -G"${work_dir}/exponential.nc"
gmt ssh3d -R0/80/0/80 -I1 -T0/40/1 -D0.05 -Mw -Q24 -G"${work_dir}/white.nc"
names=(von_karman gaussian exponential white)
titles=("Von Karman" "Gaussian" "Exponential" "White noise")
letters=(a b c d)
for name in "${names[@]}"; do
	gmt grdconvert "${work_dir}/${name}.nc?heterogeneity[20]" "${work_dir}/${name}_slice.nc"
done
gmt makecpt -Cvik -T-0.18/0.18/0.01 > "${work_dir}/field.cpt"
ps_file="${work_dir}/ex02_statistical_models.ps"
for ((i=0;i<4;i++)); do
	shift=(); ((i==0)) && shift=(-X0.8i -Y4.6i); ((i==1||i==3)) && shift=(-X3.75i); ((i==2)) && shift=(-X-3.75i -Y-4.0i)
	if ((i==0)); then
		gmt grdimage "${work_dir}/${names[i]}_slice.nc" -P -R0/80/0/80 -JX3.15i \
			-C"${work_dir}/field.cpt" -Bxa20f10+lX -Bya20f10+lY \
			-BWSen+t"(${letters[i]}) ${titles[i]}: z = 20" "${shift[@]}" -K > "${ps_file}"
	else
		gmt grdimage "${work_dir}/${names[i]}_slice.nc" -R -J -C"${work_dir}/field.cpt" \
			-Bxa20f10+lX -Bya20f10+lY -BWSen+t"(${letters[i]}) ${titles[i]}: z = 20" \
			"${shift[@]}" -O -K >> "${ps_file}"
	fi
done
gmt psscale -R -J -C"${work_dir}/field.cpt" -DjBC+w4.8i/0.15i+h+o-1.875i/-1.0i \
	-Bxa0.06+l"Fractional perturbation" --FONT_ANNOT_PRIMARY=11p --FONT_LABEL=11p -O >> "${ps_file}"
gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex02_statistical_models"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex02_statistical_models"
