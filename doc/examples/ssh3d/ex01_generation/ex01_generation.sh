#!/usr/bin/env bash
#
# Generate isotropic and anisotropic three-dimensional heterogeneities.

set -euo pipefail
gmt_executable=${GMT:-$(command -v gmt || true)}
[[ -n "${gmt_executable}" ]] || { echo "GMT was not found; set GMT=/path/to/gmt" >&2; exit 1; }
gmt() { command "${gmt_executable}" "$@"; }
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh3d-ex01.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p
gmt ssh3d -R0/100/0/100 -I1 -T0/100/1 -D0.05 -C8 -U0.3 -Q42 \
	-G"${work_dir}/isotropic.nc"
gmt ssh3d -R0/100/0/100 -I1 -T0/100/1 -D0.05 -C20/8/3 -U0.3 -Q42 \
	-G"${work_dir}/anisotropic.nc"
for name in isotropic anisotropic; do
	gmt grdconvert "${work_dir}/${name}.nc?heterogeneity[50]" \
		"${work_dir}/${name}_horizontal.nc"
	gmt grdcut "${work_dir}/${name}.nc?heterogeneity" -Ey50 \
		-G"${work_dir}/${name}_vertical.nc"
done
gmt makecpt -Cvik -T-0.16/0.16/0.01 > "${work_dir}/field.cpt"

ps_file="${work_dir}/ex01_generation.ps"
names=(isotropic isotropic anisotropic anisotropic)
views=(horizontal vertical horizontal vertical)
titles=("Isotropic: z = 50" "Isotropic: y = 50" "Anisotropic: z = 50" "Anisotropic: y = 50")
letters=(a b c d)
for ((i=0;i<4;i++)); do
	shift=()
	((i==0)) && shift=(-X0.8i -Y5.2i)
	((i==1 || i==3)) && shift=(-X3.75i)
	((i==2)) && shift=(-X-3.75i -Y-4.0i)
	ylabel=Y; [[ ${views[i]} == vertical ]] && ylabel=Z
	if ((i==0)); then
		gmt grdimage "${work_dir}/${names[i]}_${views[i]}.nc" -P -R0/100/0/100 \
			-JX3.15i -C"${work_dir}/field.cpt" -Bxa20f10+lX \
			-Bya20f10+l"${ylabel}" -BWSen+t"(${letters[i]}) ${titles[i]}" \
			"${shift[@]}" -K > "${ps_file}"
	else
		gmt grdimage "${work_dir}/${names[i]}_${views[i]}.nc" -R0/100/0/100 \
			-JX3.15i -C"${work_dir}/field.cpt" -Bxa20f10+lX \
			-Bya20f10+l"${ylabel}" -BWSen+t"(${letters[i]}) ${titles[i]}" \
			"${shift[@]}" -O -K >> "${ps_file}"
	fi
done
gmt psscale -R -J -C"${work_dir}/field.cpt" \
	-DjBC+w4.8i/0.15i+h+o-1.875i/-1.0i -Bxa0.04+l"Fractional perturbation" \
	--FONT_ANNOT_PRIMARY=11p --FONT_LABEL=11p -O >> "${ps_file}"
gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex01_generation"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex01_generation"
