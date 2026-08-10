#!/usr/bin/env bash
#
# Compare representative BLEND window functions for ssh1d tapering.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex05.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

functions=(boxcar linear cosine smoothstep gaussian plancktaper)
titles=("Boxcar" "Linear" "Cosine" "Smoothstep" "Gaussian" "Planck taper")
letters=(a b c d e f)
gmt ssh1d -T0/100/0.1 -D0.05 -C6 -U0.3 -Q17 \
	-G"${work_dir}/untapered.txt"
for function in "${functions[@]}"; do
	ratio=0.3
	if [[ "${function}" == boxcar ]]; then
		ratio=0
	fi
	gmt ssh1d -T0/100/0.1 -D0.05 -C6 -U0.3 -Q17 -L20/80 \
		-W"${function}"+r${ratio}/${ratio} \
		-G"${work_dir}/${function}.txt"
done

cat > "${work_dir}/support.txt" <<- EOF
	20 -0.2
	20 0.2
	>
	80 -0.2
	80 0.2
	EOF

region=0/100/-0.2/0.2
projection=X3.15i/1.75i
ps_file="${work_dir}/ex05_window_functions.ps"

for ((index = 0; index < ${#functions[@]}; index++)); do
	function=${functions[index]}
	letter=${letters[index]}
	shift=()
	x_label=()
	y_label=()
	if ((index == 0)); then
		shift=(-X0.8i -Y6.8i)
	fi
	if ((index == 1 || index == 3 || index == 5)); then
		shift=(-X3.75i)
	elif ((index > 0)); then
		shift=(-X-3.75i -Y-2.45i)
	fi
	if ((index >= 4)); then
		x_label=(-Bxa20f10+l"Coordinate")
	else
		x_label=(-Bxa20f10)
	fi
	if ((index % 2 == 0)); then
		y_label=(-Bya0.1f0.05+l"Fractional perturbation")
	else
		y_label=(-Bya0.1f0.05)
	fi
	if ((index == 0)); then
		gmt psbasemap -P -R${region} -J${projection} "${x_label[@]}" \
			"${y_label[@]}" -BWSen+t"(${letter}) ${titles[index]}" \
			"${shift[@]}" -K > "${ps_file}"
	else
		gmt psbasemap -R${region} -J${projection} "${x_label[@]}" \
			"${y_label[@]}" -BWSen+t"(${letter}) ${titles[index]}" \
			"${shift[@]}" -O -K >> "${ps_file}"
	fi
	gmt psxy "${work_dir}/support.txt" -R -J -W0.6p,gray55,- -O -K >> "${ps_file}"
	gmt psxy "${work_dir}/untapered.txt" -R -J -W0.8p,gray65 -O -K >> "${ps_file}"
	if ((index == 5)); then
		gmt psxy "${work_dir}/${function}.txt" -R -J \
			-W1.5p,royalblue -O >> "${ps_file}"
	else
		gmt psxy "${work_dir}/${function}.txt" -R -J \
			-W1.5p,royalblue -O -K >> "${ps_file}"
	fi
done

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex05_window_functions"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex05_window_functions"
