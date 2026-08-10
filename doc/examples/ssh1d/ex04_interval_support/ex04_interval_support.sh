#!/usr/bin/env bash
#
# Restrict and taper a heterogeneity field within an interval support.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh1d-ex04.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

raw="${work_dir}/raw.txt"
tapered="${work_dir}/tapered.txt"
gmt ssh1d -T0/100/0.1 -D0.06 -C6 -U0.3 -Q55 -G"${raw}"
gmt ssh1d -T0/100/0.1 -D0.06 -C6 -U0.3 -Q55 -L20/80 \
	-Wcosine+r0.3/0.3+w -G"${tapered}"

cat > "${work_dir}/support.txt" <<- EOF
	20 -0.20
	20 1.10
	>
	80 -0.20
	80 1.10
	EOF

ps_file="${work_dir}/ex04_interval_support.ps"
projection=X2.15i/2.5i

gmt psbasemap -P -R0/100/-0.20/0.20 -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya0.1f0.05+l"Fractional perturbation" -BWSen+t"(a) Untapered" \
	-X0.7i -Y2.0i -K > "${ps_file}"
gmt psxy "${work_dir}/support.txt" -R -J -W0.7p,gray55,- -O -K >> "${ps_file}"
gmt psxy "${raw}" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"

gmt psbasemap -R0/100/-0.20/0.20 -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya0.1f0.05 -BWSen+t"(b) Tapered in 20/80" -X2.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/support.txt" -R -J -W0.7p,gray55,- -O -K >> "${ps_file}"
gmt psxy "${tapered}" -i0,1 -R -J -W1.5p,orangered -O -K >> "${ps_file}"

gmt psbasemap -R0/100/-0.05/1.10 -J${projection} -Bxa20f10+l"Coordinate" \
	-Bya0.25f0.125+l"Weight" -BWSen+t"(c) Taper weight" -X2.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/support.txt" -R -J -W0.7p,gray55,- -O -K >> "${ps_file}"
gmt psxy "${tapered}" -i0,2 -R -J -W1.5p,seagreen -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex04_interval_support"
gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/ex04_interval_support"
