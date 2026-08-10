#!/usr/bin/env bash
#
# Compare symmetric and mixed-window tapers on an extruded 3-D support.

set -euo pipefail
gmt_executable=${GMT:-$(command -v gmt || true)}
[[ -n "${gmt_executable}" ]] || { echo "GMT was not found; set GMT=/path/to/gmt" >&2; exit 1; }
gmt() { command "${gmt_executable}" "$@"; }
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh3d-ex03.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"
gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

polygon="${work_dir}/isotoxal_star.txt"
cat > "${polygon}" <<- EOF
	50 10
	58 42
	90 50
	58 58
	50 90
	42 58
	10 50
	42 42
	50 10
	EOF
gmt ssh3d -R0/100/0/100 -I1 -T0/100/1 -D0.05 -C8/6/4 -U0.3 -Q17 \
	-P"${polygon}" -L20/80 -Wcosine/cosine/cosine+r0.3/0.3/0.3+w \
	-G"${work_dir}/cosine.nc"
gmt ssh3d -R0/100/0/100 -I1 -T0/100/1 -D0.05 -C8/6/4 -U0.3 -Q17 \
	-P"${polygon}" -L20/80 -Wplancktaper/welch/kaiser+r0.3/0.3/0.3+w \
	-G"${work_dir}/mixed.nc"
for name in cosine mixed; do
	gmt grdconvert "${work_dir}/${name}.nc?heterogeneity[50]" "${work_dir}/${name}_horizontal.nc"
	gmt grdcut "${work_dir}/${name}.nc?heterogeneity" -Ey50 -G"${work_dir}/${name}_vertical.nc"
done
gmt makecpt -Cvik -T-0.16/0.16/0.01 > "${work_dir}/heterogeneity.cpt"
cat > "${work_dir}/vertical_support.txt" <<- EOF
	10 20
	90 20
	90 80
	10 80
	EOF

ps_file="${work_dir}/ex03_support_and_windows.ps"
names=(cosine cosine mixed mixed)
views=(horizontal vertical horizontal vertical)
titles=("Cosine: z = 50" "Cosine: y = 50" "Planck/Welch/Kaiser: z = 50" "Planck/Welch/Kaiser: y = 50")
letters=(a b c d)
for ((i=0;i<4;i++)); do
	shift=(); ((i==0)) && shift=(-X0.8i -Y5.2i); ((i==1||i==3)) && shift=(-X3.75i); ((i==2)) && shift=(-X-3.75i -Y-4.0i)
	ylabel=Y; outline=${polygon}; [[ ${views[i]} == vertical ]] && { ylabel=Z; outline="${work_dir}/vertical_support.txt"; }
	if ((i==0)); then
		gmt grdimage "${work_dir}/${names[i]}_${views[i]}.nc" -P -R0/100/0/100 -JX3.15i \
			-C"${work_dir}/heterogeneity.cpt" -Bxa20f10+lX -Bya20f10+l"${ylabel}" \
			-BWSen+t"(${letters[i]}) ${titles[i]}" "${shift[@]}" -K > "${ps_file}"
	else
		gmt grdimage "${work_dir}/${names[i]}_${views[i]}.nc" -R0/100/0/100 -JX3.15i \
			-C"${work_dir}/heterogeneity.cpt" -Bxa20f10+lX -Bya20f10+l"${ylabel}" \
			-BWSen+t"(${letters[i]}) ${titles[i]}" "${shift[@]}" -O -K >> "${ps_file}"
	fi
	gmt psxy "${outline}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"
done
gmt psscale -R -J -C"${work_dir}/heterogeneity.cpt" -DjBC+w4.8i/0.15i+h+o-1.875i/-1.0i \
	-Bxa0.04+l"Fractional perturbation" --FONT_ANNOT_PRIMARY=11p --FONT_LABEL=11p -O >> "${ps_file}"
gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex03_support_and_windows"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex03_support_and_windows"
