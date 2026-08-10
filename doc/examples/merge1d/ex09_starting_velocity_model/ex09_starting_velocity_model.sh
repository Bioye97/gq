#!/usr/bin/env bash
#
# Blend the Hadley-Kanamori southern California model into AK135.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex09-velocity.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

hadley="${work_dir}/hadley_kanamori_vp.txt"
ak135="${work_dir}/ak135_vp.txt"
mergefile="${work_dir}/starting_model.merge"
merged="${work_dir}/merged_vp.txt"
ps_file="${work_dir}/ex09_starting_velocity_model.ps"

# Corrected SCSN Hadley-Kanamori model. The 7.8 km/s half-space begins at
# the 32 km Moho, where the one-sided taper has already reached zero.
awk 'BEGIN {
	for (i = 0; i <= 320; i++) {
		depth = i / 10
		if (depth < 5.5) vp = 5.5
		else if (depth < 16) vp = 6.3
		else if (depth < 32) vp = 6.7
		else vp = 7.8
		printf "%.1f %.12g\n", depth, vp
	}
}' > "${hadley}"

# Continental AK135 structure. Below 35 km, linearly interpolate the
# point-wise velocities tabulated at 35 and 77.5 km.
awk 'BEGIN {
	for (i = 0; i <= 600; i++) {
		depth = i / 10
		if (depth < 20) vp = 5.8
		else if (depth < 35) vp = 6.5
		else vp = 8.04 + (depth - 35) * (8.045 - 8.04) / (77.5 - 35)
		printf "%.1f %.12g\n", depth, vp
	}
}' > "${ak135}"

cat > "${mergefile}" <<- EOF
	${hadley} ${ak135} - cosine 0/0.2
	${ak135} - - - -
	EOF

gmt merge1d "${mergefile}" -T0/60/0.1 -W -G"${merged}"

# The shallow profile follows Hadley-Kanamori, reaches pure AK135 at the
# bottom of the taper, and then follows AK135 through 60 km.
awk 'BEGIN {expected60 = 8.04 + 25 * (8.045 - 8.04) / 42.5}
	{
		if (tolower($2) == "nan") exit 1
		if ($1 == 0) {
			v0 = $2
			if (($2 - 5.5)^2 < 1e-16 && ($3 - 1)^2 < 1e-16) shallow = 1
		}
		if ($1 == 20) {v20 = $2; if (($2 - 6.7)^2 < 1e-16) crust = 1}
		if ($1 == 32) {
			v32 = $2
			if (($2 - 6.5)^2 < 1e-6 && $3^2 < 1e-6) taper_end = 1
		}
		if ($1 == 60) {
			v60 = $2
			if (($2 - expected60)^2 < 1e-16 && $3^2 < 1e-16) deep = 1
		}
		count++
	}
	END {
		if (count != 601 || !shallow || !crust || !taper_end || !deep) {
			printf "Unexpected merged profile: count=%d Vp(0)=%g Vp(20)=%g Vp(32)=%g Vp(60)=%g\n", \
			       count, v0, v20, v32, v60 > "/dev/stderr"
			exit 1
		}
	}' "${merged}"

cat > "${work_dir}/legend.txt" <<- EOF
	S 0.08i - 0.28i - 3.0p,royalblue,- 0.35i Hadley-Kanamori
	S 0.08i - 0.28i - 3.0p,black,- 0.35i AK135
	S 0.08i - 0.28i - 1.5p,hotpink 0.35i Merged starting model
	EOF

gmt psbasemap -P -R5.2/8.2/0/60 -JX4.7i/-5.5i \
	-Bxa0.5f0.1+l"P-wave velocity (km/s)" \
	-Bya10f5+l"Depth (km)" \
	-BWSen+t"(a) Starting velocity model" \
	-X0.7i -Y0.8i -K > "${ps_file}"
gmt psxy "${hadley}" -i1,0 -R -J -W3.0p,royalblue,- \
	-O -K >> "${ps_file}"
gmt psxy "${ak135}" -i1,0 -R -J -W3.0p,black,- \
	-O -K >> "${ps_file}"
gmt psxy "${merged}" -i1,0 -R -J -W1.5p,hotpink \
	-O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend.txt" -R -J -DjBL+o0.08i \
	-F+gwhite+p0.4p -O -K >> "${ps_file}"

gmt psbasemap -R-0.05/1.05/0/60 -JX1.7i/-5.5i \
	-Bxa0.2f0.1+l"Merging weight" -Bya10f5 \
	-BwSen+t"(b) Merging weight" -X5.2i -O -K >> "${ps_file}"
gmt psxy "${merged}" -i2,0 -R -J -W1.5p,hotpink \
	-O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex09_starting_velocity_model"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex09_starting_velocity_model"
