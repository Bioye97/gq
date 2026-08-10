#!/usr/bin/env bash
#
# Aggregate multiparameter Cascadia models at 2 km depth.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
gdalbuildvrt_executable=${GDALBUILDVRT:-$(command -v gdalbuildvrt || true)}
gdal_translate_executable=${GDAL_TRANSLATE:-$(command -v gdal_translate || true)}
ncdump_executable=${NCDUMP:-$(command -v ncdump || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
if [[ -z "${gdalbuildvrt_executable}" || -z "${gdal_translate_executable}" ]]; then
	echo "GDAL was not found; set GDALBUILDVRT and GDAL_TRANSLATE" >&2
	exit 1
fi
if [[ -z "${ncdump_executable}" ]]; then
	echo "ncdump was not found; set NCDUMP=/path/to/ncdump" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}
plot_depth_label() {
	printf "%s\n" "-116.25 39.3 2 km" | \
		gmt pstext -R -J -F+f10p,Helvetica,black+jBR -Gwhite -C0.08c -O -K
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prepare_script="${script_dir}/../../data/cascadia/prepare_vs_slices.sh"
if [[ -n "${GQ_EXAMPLE_DATA:-}" ]]; then
	data_dir="${GQ_EXAMPLE_DATA}/cascadia"
else
	data_dir="${script_dir}/../../data/cascadia"
fi
GMT="${gmt_executable}" "${prepare_script}"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge2d-ex19-cascadia.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

region=-130/-116/39/52
increment=0.05
vp_cpt="${work_dir}/vp.cpt"
vs_cpt="${work_dir}/vs.cpt"
density_cpt="${work_dir}/density.cpt"
# GMT rescales colorbar fonts by sqrt(bar length / 15 cm).
colorbar_font_2col=16.4p
colorbar_font_3col=18.1p

svi_vp="${data_dir}/SVI-EQTOMO-Savard2018-Vp-2km.nc"
svi_vs="${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
svi_density="${data_dir}/SVI-EQTOMO-Savard2018-Density-2km.nc"
casc16_vp="${data_dir}/casc1.6-velmdl-Vp-2km.nc"
casc16_vs="${data_dir}/casc1.6-velmdl-Vs-2km.nc"
wus324_vp="${data_dir}/WUS324-Casc-Vp-2km.nc"
wus324_vs="${data_dir}/WUS324-Casc-Vs-2km.nc"
wus324_density="${data_dir}/WUS324-Casc-Density-2km.nc"

make_multivariable_model() {
	local output=$1
	shift
	local vrt="${output%.nc}.vrt"
	"${gdalbuildvrt_executable}" -q -separate "${vrt}" "$@"
	"${gdal_translate_executable}" -q -of netCDF -co FORMAT=NC4 \
		"${vrt}" "${output}"
}

svi_vp_vs="${work_dir}/svi_vp_vs.nc"
casc16_vp_vs="${work_dir}/casc16_vp_vs.nc"
wus324_vp_vs="${work_dir}/wus324_vp_vs.nc"
svi_vp_vs_density="${work_dir}/svi_vp_vs_density.nc"
wus324_vp_vs_density="${work_dir}/wus324_vp_vs_density.nc"
casc16_vp_aligned="${work_dir}/casc16_vp_aligned.nc"
casc16_vs_aligned="${work_dir}/casc16_vs_aligned.nc"

make_multivariable_model "${svi_vp_vs}" "${svi_vp}" "${svi_vs}"
gmt grdsample "${casc16_vp}" -R-130.1/-121/40.2/50 -I${increment} \
	-rg -nl+c -G"${casc16_vp_aligned}"
gmt grdsample "${casc16_vs}" -R-130.1/-121/40.2/50 -I${increment} \
	-rg -nl+c -G"${casc16_vs_aligned}"
make_multivariable_model "${casc16_vp_vs}" \
	"${casc16_vp_aligned}" "${casc16_vs_aligned}"
make_multivariable_model "${wus324_vp_vs}" "${wus324_vp}" "${wus324_vs}"
make_multivariable_model "${svi_vp_vs_density}" \
	"${svi_vp}" "${svi_vs}" "${svi_density}"
make_multivariable_model "${wus324_vp_vs_density}" \
	"${wus324_vp}" "${wus324_vs}" "${wus324_density}"

vp_vs_tiled="${work_dir}/vp_vs_tiled.nc"
vp_vs_aggregate="${work_dir}/vp_vs_aggregate.nc"
vp_vs_mergefile="${work_dir}/vp_vs.merge2d"

# Band1 and Band2 map positionally to the final vp and vs variable names.
gmt merge2d "${svi_vp_vs}?Band1,Band2" \
	"${casc16_vp_vs}?Band1,Band2" "${wus324_vp_vs}?Band1,Band2" \
	-R${region} -I${increment} -Cf -Fvp,vs -G"${vp_vs_tiled}"
cat > "${vp_vs_mergefile}" <<- EOF
	${svi_vp_vs}?Band1,Band2 ${wus324_vp_vs}?Band1,Band2 - cosine/cosine 0.49
	${casc16_vp_vs}?Band1,Band2 ${wus324_vp_vs}?Band1,Band2 - cosine/cosine 0.49
	${wus324_vp_vs}?Band1,Band2 - - - -
	EOF
gmt merge2d "${vp_vs_mergefile}" -R${region} -I${increment} -A -P \
	-Fvp,vs -G"${vp_vs_aggregate}"

vp_vs_density_tiled="${work_dir}/vp_vs_density_tiled.nc"
vp_vs_density_aggregate="${work_dir}/vp_vs_density_aggregate.nc"
vp_vs_density_mergefile="${work_dir}/vp_vs_density.merge2d"

# Band1, Band2, and Band3 map to vp, vs, and density.
gmt merge2d "${svi_vp_vs_density}?Band1,Band2,Band3" \
	"${wus324_vp_vs_density}?Band1,Band2,Band3" \
	-R${region} -I${increment} -Cf -Fvp,vs,density \
	-G"${vp_vs_density_tiled}"
cat > "${vp_vs_density_mergefile}" <<- EOF
	${svi_vp_vs_density}?Band1,Band2,Band3 ${wus324_vp_vs_density}?Band1,Band2,Band3 - cosine/cosine 0.49
	${wus324_vp_vs_density}?Band1,Band2,Band3 - - - -
	EOF
gmt merge2d "${vp_vs_density_mergefile}" -R${region} -I${increment} \
	-A -P -Fvp,vs,density -G"${vp_vs_density_aggregate}"

for output in "${vp_vs_tiled}" "${vp_vs_aggregate}"; do
	"${ncdump_executable}" -h "${output}" > "${output}.header"
	grep -Eq '(float|double) vp\(' "${output}.header"
	grep -Eq '(float|double) vs\(' "${output}.header"
done
for output in "${vp_vs_density_tiled}" "${vp_vs_density_aggregate}"; do
	"${ncdump_executable}" -h "${output}" > "${output}.header"
	for field in vp vs density; do
		grep -Eq "(float|double) ${field}\\(" "${output}.header"
	done
done
for field in vp vs; do
	gmt grdmath "${vp_vs_aggregate}?${field}" "${vp_vs_tiled}?${field}" \
		SUB = "${work_dir}/vp_vs_${field}_difference.nc"
	gmt grdinfo "${work_dir}/vp_vs_${field}_difference.nc" -C | \
		awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
done
for field in vp vs density; do
	gmt grdmath "${vp_vs_density_aggregate}?${field}" \
		"${vp_vs_density_tiled}?${field}" SUB = \
		"${work_dir}/vp_vs_density_${field}_difference.nc"
	gmt grdinfo "${work_dir}/vp_vs_density_${field}_difference.nc" -C | \
		awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
done

gmt set FONT_ANNOT_PRIMARY 9p FONT_LABEL 10p FONT_TITLE 10p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 12p COLOR_NAN white
gmt makecpt -Cturbo -T1.5/9/0.25 -Z > "${vp_cpt}"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${vs_cpt}"
gmt makecpt -Cturbo -T2.3/3.5/0.05 -Z > "${density_cpt}"

# Figure 1: Vp and Vs from SVI EQTOMO, Cascadia v1.6, and WUS324.
projection=M2.55i
ps_file="${work_dir}/ex19_cascadia_vp_vs.ps"

gmt grdimage "${vp_vs_tiled}?vp" -P -R${region} -J${projection} -C"${vp_cpt}" \
	-Bxa5f1 -Bya5f1+l"Latitude" -BWSen+t"(a) Vp tiling" \
	-X0.7i -Y5.2i -K > "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"

gmt grdimage "${vp_vs_tiled}?vs" -R -J -C"${vs_cpt}" \
	-Bxa5f1 -Bya5f1 -BWSen+t"(b) Vs tiling" -X3.25i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"

gmt grdimage "${vp_vs_aggregate}?vp" -R -J -C"${vp_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1+l"Latitude" \
	-BWSen+t"(c) Vp aggregate" -X-3.25i -Y-4.2i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"
gmt psscale -R -J -C"${vp_cpt}" -DjBC+w2.2i/0.11i+h+o0/-0.7i \
	-Bxa1f0.5+l"Vp (km/s)" \
	--FONT_ANNOT_PRIMARY=${colorbar_font_2col} \
	--FONT_LABEL=${colorbar_font_2col} -O -K >> "${ps_file}"

gmt grdimage "${vp_vs_aggregate}?vs" -R -J -C"${vs_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1 -BWSen+t"(d) Vs aggregate" \
	-X3.25i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"
gmt psscale -R -J -C"${vs_cpt}" -DjBC+w2.2i/0.11i+h+o0/-0.7i \
	-Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=${colorbar_font_2col} \
	--FONT_LABEL=${colorbar_font_2col} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/ex19_cascadia_vp_vs"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex19_cascadia_vp_vs"

# Figure 2: Vp, Vs, and density from SVI EQTOMO and WUS324.
projection=M2.2i
ps_file="${work_dir}/ex19_cascadia_vp_vs_density.ps"

gmt grdimage "${vp_vs_density_tiled}?vp" -P -R${region} -J${projection} \
	-C"${vp_cpt}" -Bxa5f1 -Bya5f1+l"Latitude" -BWSen+t"(a) Vp tiling" \
	-X0.45i -Y5.2i -K > "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"

gmt grdimage "${vp_vs_density_tiled}?vs" -R -J -C"${vs_cpt}" \
	-Bxa5f1 -Bya5f1 -BWSen+t"(b) Vs tiling" -X2.75i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"

gmt grdimage "${vp_vs_density_tiled}?density" -R -J -C"${density_cpt}" \
	-Bxa5f1 -Bya5f1 -BWSen+t"(c) Density tiling" -X2.75i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"

gmt grdimage "${vp_vs_density_aggregate}?vp" -R -J -C"${vp_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1+l"Latitude" \
	-BWSen+t"(d) Vp aggregate" -X-5.5i -Y-3.9i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"
gmt psscale -R -J -C"${vp_cpt}" -DjBC+w1.8i/0.1i+h+o0/-0.7i \
	-Bxa1f0.5+l"Vp (km/s)" \
	--FONT_ANNOT_PRIMARY=${colorbar_font_3col} \
	--FONT_LABEL=${colorbar_font_3col} -O -K >> "${ps_file}"

gmt grdimage "${vp_vs_density_aggregate}?vs" -R -J -C"${vs_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1 -BWSen+t"(e) Vs aggregate" \
	-X2.75i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"
gmt psscale -R -J -C"${vs_cpt}" -DjBC+w1.8i/0.1i+h+o0/-0.7i \
	-Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=${colorbar_font_3col} \
	--FONT_LABEL=${colorbar_font_3col} -O -K >> "${ps_file}"

gmt grdimage "${vp_vs_density_aggregate}?density" -R -J \
	-C"${density_cpt}" -Bxa5f1+l"Longitude" -Bya5f1 \
	-BWSen+t"(f) Density aggregate" -X2.75i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
plot_depth_label >> "${ps_file}"
gmt psscale -R -J -C"${density_cpt}" -DjBC+w1.8i/0.1i+h+o0/-0.7i \
	-Bxa0.2f0.1+l"Density (g/cm@+3@+)" \
	--FONT_ANNOT_PRIMARY=${colorbar_font_3col} \
	--FONT_LABEL=${colorbar_font_3col} \
	-O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex19_cascadia_vp_vs_density"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex19_cascadia_vp_vs_density"
