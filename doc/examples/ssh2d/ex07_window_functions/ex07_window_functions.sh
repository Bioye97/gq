#!/usr/bin/env bash
#
# Compare representative BLEND windows on a two-dimensional support.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex07.XXXXXX")
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
functions=(boxcar linear cosine smoothstep gaussian plancktaper)
titles=("Boxcar" "Linear" "Cosine" "Smoothstep" "Gaussian" "Planck taper")
letters=(a b c d e f)
for function in "${functions[@]}"; do
	ratio=0.3
	if [[ "${function}" == boxcar ]]; then ratio=0; fi
	gmt ssh2d -R0/100/0/100 -I1 -D0.05 -C7 -U0.3 -Q17 \
		-P"${polygon}" -W"${function}"+r${ratio}+w \
		-G"${work_dir}/${function}.nc"
done
gmt makecpt -Cvik -T-0.16/0.16/0.01 > "${work_dir}/heterogeneity.cpt"

projection=X2.15i
ps_file="${work_dir}/ex07_window_functions.ps"
for ((index = 0; index < 6; index++)); do
	shift=()
	if ((index == 0)); then shift=(-X0.7i -Y7.5i); fi
	if ((index == 1 || index == 3 || index == 5)); then shift=(-X2.75i); fi
	if ((index == 2 || index == 4)); then shift=(-X-2.75i -Y-3.1i); fi
	xaxis=-Bxa20f10
	yaxis=-Bya20f10
	if ((index >= 4)); then xaxis=-Bxa20f10+lX; fi
	if ((index % 2 == 0)); then yaxis=-Bya20f10+lY; fi
	if ((index == 0)); then
		gmt grdimage "${work_dir}/${functions[index]}.nc?heterogeneity" -P \
			-R0/100/0/100 -J${projection} -C"${work_dir}/heterogeneity.cpt" \
			"${xaxis}" "${yaxis}" -BWSen+t"(${letters[index]}) ${titles[index]}" \
			"${shift[@]}" -K > "${ps_file}"
	else
		gmt grdimage "${work_dir}/${functions[index]}.nc?heterogeneity" \
			-R0/100/0/100 -J${projection} -C"${work_dir}/heterogeneity.cpt" \
			"${xaxis}" "${yaxis}" -BWSen+t"(${letters[index]}) ${titles[index]}" \
			"${shift[@]}" -O -K >> "${ps_file}"
	fi
	gmt psxy "${polygon}" -R -J -L -W1p,orangered,- -O -K >> "${ps_file}"
done
gmt psscale -R -J -C"${work_dir}/heterogeneity.cpt" \
	-DjBC+w4.2i/0.15i+h+o-1.375i/-1.0i \
	-Bxa0.08+l"Fractional perturbation" \
	--FONT_ANNOT_PRIMARY=12p --FONT_LABEL=12p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex07_window_functions"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex07_window_functions"
