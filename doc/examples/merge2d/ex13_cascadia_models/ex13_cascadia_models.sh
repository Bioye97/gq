#!/usr/bin/env bash
#
# Compare tiling, cosine merging, and aggregate merging of Cascadia Vs models.

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
prepare_script="${script_dir}/../../data/cascadia/prepare_vs_slices.sh"
if [[ -n "${GQ_EXAMPLE_DATA:-}" ]]; then
	data_dir="${GQ_EXAMPLE_DATA}/cascadia"
else
	data_dir="${script_dir}/../../data/cascadia"
fi
GMT="${gmt_executable}" "${prepare_script}"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex13-cascadia.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

svi="${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
ant_rf="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
casc16="${data_dir}/casc1.6-velmdl-Vs-2km.nc"
wus324="${data_dir}/WUS324-Casc-Vs-2km.nc"

region=-130/-116/39/52
increment=0.05
projection=M2.2i
velocity_cpt="${work_dir}/velocity.cpt"
colorbar_font=9.8p

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"

make_comparison() {
	local primary=$1
	local name=$2
	local mergefile="${work_dir}/${name}.merge2d"
	local tiled="${work_dir}/${name}_tiled.nc"
	local merged="${work_dir}/${name}_merged.nc"
	local aggregate="${work_dir}/${name}_aggregate.nc"
	local difference="${work_dir}/${name}_difference.nc"
	local aggregate_difference="${work_dir}/${name}_aggregate_difference.nc"
	local svi_outline="${work_dir}/${name}_svi_outline.txt"
	local primary_outline="${work_dir}/${name}_primary_outline.txt"
	local ps_file="${work_dir}/${name}.ps"

	# Tile by first availability: SVI EQTOMO, the regional model, then WUS324.
	gmt merge2d "${svi}" "${primary}" "${wus324}" -R${region} \
		-I${increment} -Cf -G"${tiled}"

	# Both regional primaries merge independently into the full-domain WUS324.
	cat > "${mergefile}" <<- EOF
		${svi} ${wus324} - cosine/cosine 0.2
		${primary} ${wus324} - cosine/cosine 0.2
		${wus324} - - - -
		EOF
	gmt merge2d "${mergefile}" -R${region} -I${increment} -P -G"${merged}"
	gmt merge2d "${mergefile}" -R${region} -I${increment} -A -P \
		-G"${aggregate}"

	gmt grdmath "${merged}" "${tiled}" SUB = "${difference}"
	gmt grdinfo "${difference}" -C | \
		awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
	gmt grdmath "${aggregate}" "${merged}" SUB = "${aggregate_difference}"
	gmt grdinfo "${aggregate_difference}" -C | \
		awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'

	# Outline the full grid domains of the two primary models in panel (a).
	gmt grdinfo "${svi}" -C | awk '{
		print $2, $4; print $3, $4; print $3, $5; print $2, $5; print $2, $4
	}' > "${svi_outline}"
	gmt grdinfo "${primary}" -C | awk '{
		print $2, $4; print $3, $4; print $3, $5; print $2, $5; print $2, $4
	}' > "${primary_outline}"

	gmt grdimage "${tiled}" -P -R${region} -J${projection} \
		-C"${velocity_cpt}" -Bxa5f1+l"Longitude" -Bya5f1+l"Latitude" \
		-BWSen+t"(a) Tiling" -X0.45i -Y2.0i -K > "${ps_file}"
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
	gmt psxy "${svi_outline}" -R -J -W1.5p,black -O -K >> "${ps_file}"
	gmt psxy "${primary_outline}" -R -J -W1.5p,black -O -K >> "${ps_file}"
	printf "%s\n" "-116.25 39.3 2 km" | \
		gmt pstext -R -J -F+f10p,Helvetica,black+jBR -Gwhite -C0.08c \
		-O -K >> "${ps_file}"

	gmt grdimage "${merged}" -R -J -C"${velocity_cpt}" \
		-Bxa5f1+l"Longitude" -Bya5f1 -BWSen+t"(b) Cosine merging" \
		-X2.75i -O -K >> "${ps_file}"
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
	printf "%s\n" "-116.25 39.3 2 km" | \
		gmt pstext -R -J -F+f10p,Helvetica,black+jBR -Gwhite -C0.08c \
		-O -K >> "${ps_file}"

	gmt grdimage "${aggregate}" -R -J -C"${velocity_cpt}" \
		-Bxa5f1+l"Longitude" -Bya5f1 -BWSen+t"(c) Aggregate merging" \
		-X2.75i -O -K >> "${ps_file}"
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
	printf "%s\n" "-116.25 39.3 2 km" | \
		gmt pstext -R -J -F+f10p,Helvetica,black+jBR -Gwhite -C0.08c \
		-O -K >> "${ps_file}"
	gmt psscale -R -J -C"${velocity_cpt}" \
		-Dx-5.5i/-0.7i+w7.7i/0.13i+h \
		-Bxa1f0.5+l"Vs (km/s)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
		--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

	gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/${name}"
	gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/${name}"
}

make_comparison "${ant_rf}" ex13_cascadia_ant_rf
make_comparison "${casc16}" ex13_cascadia_v16
