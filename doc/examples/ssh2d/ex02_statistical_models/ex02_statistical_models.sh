#!/usr/bin/env bash
#
# Compare the statistical models available in ssh2d.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex02.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

gmt ssh2d -R0/100/0/100 -I1 -D0.05 -C8 -U0.15 -Mv -Q24 -G"${work_dir}/von_karman.nc"
gmt ssh2d -R0/100/0/100 -I1 -D0.05 -C8 -Mg -Q24 -G"${work_dir}/gaussian.nc"
gmt ssh2d -R0/100/0/100 -I1 -D0.05 -C8 -Me -Q24 -G"${work_dir}/exponential.nc"
gmt ssh2d -R0/100/0/100 -I1 -D0.05 -Mw -Q24 -G"${work_dir}/white.nc"
gmt makecpt -Cvik -T-0.18/0.18/0.01 > "${work_dir}/heterogeneity.cpt"

names=(von_karman gaussian exponential white)
titles=("Von Karman" "Gaussian" "Exponential" "White noise")
letters=(a b c d)
projection=X3.15i
ps_file="${work_dir}/ex02_statistical_models.ps"

for ((index = 0; index < 4; index++)); do
	shift=()
	if ((index == 0)); then shift=(-X0.8i -Y5.2i); fi
	if ((index == 1)); then shift=(-X3.75i); fi
	if ((index == 2)); then shift=(-X-3.75i -Y-4.0i); fi
	if ((index == 3)); then shift=(-X3.75i); fi
	xaxis=-Bxa20f10
	yaxis=-Bya20f10
	if ((index >= 2)); then xaxis=-Bxa20f10+lX; fi
	if ((index % 2 == 0)); then yaxis=-Bya20f10+lY; fi
	if ((index == 0)); then
		gmt grdimage "${work_dir}/${names[index]}.nc?heterogeneity" -P \
			-R0/100/0/100 -J${projection} -C"${work_dir}/heterogeneity.cpt" \
			"${xaxis}" "${yaxis}" -BWSen+t"(${letters[index]}) ${titles[index]}" \
			"${shift[@]}" -K > "${ps_file}"
	else
		gmt grdimage "${work_dir}/${names[index]}.nc?heterogeneity" \
			-R0/100/0/100 -J${projection} -C"${work_dir}/heterogeneity.cpt" \
			"${xaxis}" "${yaxis}" -BWSen+t"(${letters[index]}) ${titles[index]}" \
			"${shift[@]}" -O -K >> "${ps_file}"
	fi
done
gmt psscale -R -J -C"${work_dir}/heterogeneity.cpt" \
	-DjBC+w4.8i/0.15i+h+o-1.875i/-1.0i \
	-Bxa0.06+l"Fractional perturbation" \
	--FONT_ANNOT_PRIMARY=11p --FONT_LABEL=11p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex02_statistical_models"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex02_statistical_models"
