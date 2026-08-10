#!/usr/bin/env bash
#
# Compare symmetric tapers, asymmetric taper ratios, and mixed X/Y windows.

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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex11-asymmetric.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

region=0/100/0/100
increment=1
projection=X2.15i/2.15i
primary="${work_dir}/primary.nc"
secondary="${work_dir}/secondary.nc"
support="${work_dir}/support.txt"
weight_cpt="${work_dir}/weights.cpt"
ps_file="${work_dir}/ex11_asymmetric_windows.ps"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font=11.45p

gmt grdmath -R15/85/15/85 -I${increment} 8 = "${primary}"
gmt grdmath -R${region} -I${increment} 2 = "${secondary}"
printf "15 15\n85 15\n85 85\n15 85\n" > "${support}"

make_merge() {
	local name=$1
	local functions=$2
	local ratios=$3
	local mergefile="${work_dir}/${name}.merge2d"
	local output="${work_dir}/${name}.nc"
	cat > "${mergefile}" <<- EOF
		${primary} ${secondary} - ${functions} ${ratios}
		${secondary} - - - -
		EOF
	gmt merge2d "${mergefile}" -R${region} -I${increment} -W -G"${output}"
}

# First vary taper symmetry, then hold the asymmetric ratios fixed while
# changing the functions used along x and y.
make_merge symmetric cosine/cosine 0.25
make_merge asymmetric_x cosine/cosine 0.05/0.40/0.25/0.25
make_merge asymmetric_xy cosine/cosine 0.05/0.40/0.15/0.35
make_merge trapezoid_gaussian trapezoid/gaussian 0.05/0.40/0.15/0.35
make_merge planck_welch plancktaper/welch 0.05/0.40/0.15/0.35
make_merge hamming_logistic hamming/logistic 0.05/0.40/0.15/0.35

outputs=(
	symmetric asymmetric_x asymmetric_xy
	trapezoid_gaussian planck_welch hamming_logistic
)

# Every result must follow the constant-field weighted combination exactly.
for name in "${outputs[@]}"; do
	output="${work_dir}/${name}.nc"
	gmt grdmath "${output}?z" "${output}?weight" 6 MUL 2 ADD SUB = \
		"${work_dir}/${name}_difference.nc"
	gmt grdinfo "${work_dir}/${name}_difference.nc" -C | \
		awk '$6 < -1e-5 || $7 > 1e-5 {exit 1}'
	gmt grdinfo "${output}?weight" -C | \
		awk '$6 < -1e-6 || $7 > 1.000001 {exit 1}'
done

# The baseline is symmetric about both coordinate axes.
printf "20 50\n80 50\n50 20\n50 80\n" | \
	gmt grdtrack -G"${work_dir}/symmetric.nc?weight" > \
	"${work_dir}/symmetric_samples.txt"
awk 'NR == 1 {west = $3}
	 NR == 2 && (($3 - west > 1e-6) || (west - $3 > 1e-6)) {exit 1}
	 NR == 3 {south = $3}
	 NR == 4 && (($3 - south > 1e-6) || (south - $3 > 1e-6)) {exit 1}' \
	"${work_dir}/symmetric_samples.txt"

# The four ratios create stronger weights toward the west and south.
printf "20 50\n80 50\n50 20\n50 80\n" | \
	gmt grdtrack -G"${work_dir}/asymmetric_xy.nc?weight" > \
	"${work_dir}/asymmetric_samples.txt"
awk 'NR == 1 {west = $3}
	 NR == 2 && west <= $3 {exit 1}
	 NR == 3 {south = $3}
	 NR == 4 && south <= $3 {exit 1}' \
	"${work_dir}/asymmetric_samples.txt"

# Mixed function pairs must differ from the all-cosine asymmetric weight.
for name in trapezoid_gaussian planck_welch hamming_logistic; do
	gmt grdmath "${work_dir}/${name}.nc?weight" \
		"${work_dir}/asymmetric_xy.nc?weight" SUB ABS = \
		"${work_dir}/${name}_window_difference.nc"
	gmt grdinfo "${work_dir}/${name}_window_difference.nc" -C | \
		awk '$7 <= 0.01 {exit 1}'
done

gmt makecpt -Chot -T0/1/0.1 -Z > "${weight_cpt}"

# Panel (a): symmetric function and ratios.
gmt grdimage "${work_dir}/symmetric.nc?weight" -P \
	-R${region} -J${projection} -C"${weight_cpt}" \
	-Bxa20f10 -Bya20f10+l"Y" -BWSen+t"(a) Symmetric cosine" \
	-X0.45i -Y4.2i -K > "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

# Panel (b): only the west and east taper ratios differ.
gmt grdimage "${work_dir}/asymmetric_x.nc?weight" -R -J -C"${weight_cpt}" \
	-Bxa20f10 -Byf10 -BWSen+t"(b) Asymmetric x" \
	-X2.7i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

# Panel (c): all four taper ratios differ.
gmt grdimage "${work_dir}/asymmetric_xy.nc?weight" -R -J -C"${weight_cpt}" \
	-Bxa20f10 -Byf10 -BWSen+t"(c) Asymmetric x and y" \
	-X2.7i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

# Panel (d): linear x taper and Gaussian y taper.
gmt grdimage "${work_dir}/trapezoid_gaussian.nc?weight" \
	-R -J -C"${weight_cpt}" \
	-Bxa20f10+l"X" -Bya20f10+l"Y" -BWSen+t"(d) Trapezoid / Gaussian" \
	-X-5.4i -Y-3.1i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

# Panel (e): Planck taper in x and Welch taper in y.
gmt grdimage "${work_dir}/planck_welch.nc?weight" -R -J -C"${weight_cpt}" \
	-Bxf10 -Byf10 -BWSen+t"(e) Planck taper / Welch" \
	-X2.7i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

# Panel (f): Hamming taper in x and logistic taper in y.
gmt grdimage "${work_dir}/hamming_logistic.nc?weight" -R -J -C"${weight_cpt}" \
	-Bxa20f10+l"X" -Byf10 -BWSen+t"(f) Hamming / Logistic" \
	-X2.7i -O -K >> "${ps_file}"
gmt psxy "${support}" -R -J -L -W1.5p,orangered,- -O -K >> "${ps_file}"

gmt psscale -R -J -C"${weight_cpt}" -DjBC+w4.5i/0.12i+h+o0/-0.75i \
	-Bxa0.2f0.1+l"Merging weight" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -X-2.7i -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex11_asymmetric_windows"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex11_asymmetric_windows"
