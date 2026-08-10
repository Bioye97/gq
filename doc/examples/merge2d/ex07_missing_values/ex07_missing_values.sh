#!/usr/bin/env bash
#
# Demonstrate fallback behavior for NaN and sentinel-valued grid nodes.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex07-missing.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
projection=X2.15i/2.15i
primary="${work_dir}/primary.nc"
primary_full="${work_dir}/primary_full.nc"
secondary="${work_dir}/secondary.nc"
secondary_clean="${work_dir}/secondary_clean.nc"
mergefile="${work_dir}/missing.merge2d"
merged="${work_dir}/merged.nc"
merged_filled="${work_dir}/merged_filled.nc"
ps_file="${work_dir}/ex07_missing_values.ps"
value_cpt="${work_dir}/values.cpt"
weight_cpt="${work_dir}/weights.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=18.4p

# The primary stores a vertical missing band as NaN.
gmt grdmath -R15/85/15/85 -I${increment} \
	X 42 GE X 58 LE MUL Y 25 GE MUL Y 75 LE MUL NaN 8 IFELSE = \
	"${primary}"
gmt grdmath -R${region} -I${increment} \
	X 15 GE X 85 LE MUL Y 15 GE MUL Y 85 LE MUL \
	X 42 GE X 58 LE MUL Y 25 GE MUL Y 75 LE MUL NaN 8 IFELSE \
	NaN IFELSE = "${primary_full}"

# The secondary stores a horizontal missing band as an undeclared sentinel.
gmt grdmath -R${region} -I${increment} \
	X 25 GE X 75 LE MUL Y 42 GE MUL Y 58 LE MUL -99999 2 IFELSE = \
	"${secondary}"
gmt grdmath "${secondary}" -99999 NAN = "${secondary_clean}"

cat > "${mergefile}" <<- EOF
	${primary} ${secondary} - cosine/cosine 0.25
	${secondary} - - - -
	EOF
gmt merge2d "${mergefile}" -R${region} -I${increment} \
	-di-99999 -W -G"${merged}"
gmt merge2d "${mergefile}" -R${region} -I${increment} \
	-di-99999 -Hl -W -G"${merged_filled}"

# Reconstruct the merge, including one-source fallback and two-source NaN.
gmt grdmath "${merged}?weight" "${primary_full}" MUL \
	1 "${merged}?weight" SUB "${secondary_clean}" MUL ADD = \
	"${work_dir}/weighted.nc"
gmt grdmath "${primary_full}" ISNAN "${secondary_clean}" \
	"${secondary_clean}" ISNAN "${primary_full}" "${work_dir}/weighted.nc" \
	IFELSE IFELSE = "${work_dir}/expected.nc"
gmt grdmath "${merged}?z" "${work_dir}/expected.nc" SUB = \
	"${work_dir}/difference.nc"
gmt grdinfo "${work_dir}/difference.nc" -C | \
	awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
gmt grdinfo "${merged}?weight" -C | \
	awk '$6 < 0 || $7 > 1 {exit 1}'

# Check primary fallback, secondary fallback, and the shared missing area.
printf "50 30\n30 50\n50 50\n" | \
	gmt grdtrack -G"${merged}?z" > "${work_dir}/samples.txt"
awk 'NR == 1 && ($3 < 1.99999 || $3 > 2.00001) {exit 1}
	 NR == 2 && ($3 < 7.99999 || $3 > 8.00001) {exit 1}
	 NR == 3 && tolower($3) != "nan" {exit 1}' "${work_dir}/samples.txt"
gmt grdinfo "${merged_filled}?z" -C | \
	awk '$6 != $6 || $7 != $7 {exit 1}'

gmt makecpt -Cturbo -T2/8/1 -Z > "${value_cpt}"
gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

# Panel (a): the primary uses NaN for its vertical missing band.
gmt grdimage "${primary}" -P -R${region} -J${projection} -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10+l"Y" -BWSen+t"(a) Primary: NaN" \
	-X0.45i -Y4.5i -K > "${ps_file}"
printf "15 15\n85 15\n85 85\n15 85\n" | \
	gmt psxy -R -J -L -W1.5p,black,- -O -K >> "${ps_file}"
printf "42 25\n58 25\n58 75\n42 75\n" | \
	gmt psxy -R -J -L -W1.5p,royalblue,- -O -K >> "${ps_file}"

# Panel (b): -di-99999 identifies the secondary sentinel as missing.
gmt grdimage "${secondary_clean}" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(b) Secondary: -99999" \
	-X2.7i -O -K >> "${ps_file}"
printf "25 42\n75 42\n75 58\n25 58\n" | \
	gmt psxy -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

# Panel (c): missing values do not alter the merging weight.
gmt grdimage "${merged}?weight" -R -J -C"${weight_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(c) Merging weight" \
	-X2.7i -O -K >> "${ps_file}"
printf "15 15\n85 15\n85 85\n15 85\n" | \
	gmt psxy -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${weight_cpt}" -DjBC+w1.75i/0.12i+h+o0/-0.75i \
	-Bxa0.2f0.1+l"Weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"

# Panel (d): retain an available member and return NaN if both are missing.
gmt grdimage "${merged}?z" -R -J -C"${value_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(d) Merged without filling" \
	-X-4.05i -Y-3.45i -O -K >> "${ps_file}"
printf "42 25\n58 25\n58 75\n42 75\n" | \
	gmt psxy -R -J -L -W1.5p,royalblue,- -O -K >> "${ps_file}"
printf "25 42\n75 42\n75 58\n25 58\n" | \
	gmt psxy -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

# Panel (e): -Hl bridges both internal gaps before merging.
gmt grdimage "${merged_filled}?z" -R -J -C"${value_cpt}" \
	-Bxa20f10 -Bya20f10 -BWSen+t"(e) Internal gaps filled" \
	-X2.7i -O -K >> "${ps_file}"
printf "42 25\n58 25\n58 75\n42 75\n" | \
	gmt psxy -R -J -L -W1.5p,royalblue,- -O -K >> "${ps_file}"
printf "25 42\n75 42\n75 58\n25 58\n" | \
	gmt psxy -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psscale -R -J -C"${value_cpt}" -DjBC+w1.75i/0.12i+h+o0/-0.85i \
	-Bxa2f1+l"Value" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex07_missing_values"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex07_missing_values"
