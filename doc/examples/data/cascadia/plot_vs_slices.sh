#!/usr/bin/env bash
#
# Plot horizontal and vertical Vs slices from five public Cascadia models.

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
if [[ -n "${GQ_EXAMPLE_DATA:-}" ]]; then
	data_dir="${GQ_EXAMPLE_DATA}/cascadia"
else
	data_dir="${script_dir}"
fi
GMT="${gmt_executable}" "${script_dir}/prepare_vs_slices.sh"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-cascadia-plot.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

delph_slice="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
porritt_slice="${data_dir}/PNW10-S-Vs-2km.nc"
savard_slice="${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
wus324_slice="${data_dir}/WUS324-Casc-Vs-2km.nc"
casc16_slice="${data_dir}/casc1.6-velmdl-Vs-2km.nc"
delph_vertical="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-lat47.nc"
porritt_vertical="${data_dir}/PNW10-S-Vs-lat47.nc"
savard_vertical="${data_dir}/SVI-EQTOMO-Savard2018-Vs-lat47.nc"
wus324_vertical="${data_dir}/WUS324-Casc-Vs-lat47.nc"
casc16_vertical="${data_dir}/casc1.6-velmdl-Vs-lat47.nc"

gmt set FONT_ANNOT_PRIMARY 9p FONT_LABEL 10p FONT_TITLE 10p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 12p COLOR_NAN white

region=-130/-116/39/52
projection=M2.3i
ps_file="${work_dir}/cascadia_vs_slices.ps"
velocity_cpt="${work_dir}/velocity.cpt"
colorbar_font=10.6p
section_latitude=47
profile_pen=1.5p,black,--

gmt makecpt -Cturbo -T0/5/0.1 -Z > "${velocity_cpt}"

gmt grdimage "${delph_slice}" -P -R${region} -J${projection} \
	-C"${velocity_cpt}" -Bxa5f1 -Bya5f1+l"Latitude" \
	-BWSen+t"(a) Cascadia ANT+RF" -X0.45i -Y5.0i -K > "${ps_file}"
gmt pscoast -R -J -W0.6p,black -N1/0.4p,gray30 -O -K >> "${ps_file}"
printf "%s %s\n%s %s\n" -130 "${section_latitude}" -116 \
	"${section_latitude}" | gmt psxy -R -J -W${profile_pen} -O -K >> "${ps_file}"

gmt grdimage "${porritt_slice}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1 -Bya5f1 -BwSen+t"(b) PNW10-S" \
	-X2.65i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.6p,black -N1/0.4p,gray30 -O -K >> "${ps_file}"
printf "%s %s\n%s %s\n" -130 "${section_latitude}" -116 \
	"${section_latitude}" | gmt psxy -R -J -W${profile_pen} -O -K >> "${ps_file}"

gmt grdimage "${savard_slice}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1 -Bya5f1 -BwSen+t"(c) SVI EQTOMO" \
	-X2.65i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.6p,black -N1/0.4p,gray30 -O -K >> "${ps_file}"
printf "%s %s\n%s %s\n" -130 "${section_latitude}" -116 \
	"${section_latitude}" | gmt psxy -R -J -W${profile_pen} -O -K >> "${ps_file}"

gmt grdimage "${wus324_slice}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1+l"Latitude" \
	-BwSen+t"(d) WUS324 Cascadia" -X-3.975i -Y-3.8i \
	-O -K >> "${ps_file}"
gmt pscoast -R -J -W0.6p,black -N1/0.4p,gray30 -O -K >> "${ps_file}"
printf "%s %s\n%s %s\n" -130 "${section_latitude}" -116 \
	"${section_latitude}" | gmt psxy -R -J -W${profile_pen} -O -K >> "${ps_file}"

gmt grdimage "${casc16_slice}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya5f1 -BwSen+t"(e) Cascadia v1.6" \
	-X2.65i -O -K >> "${ps_file}"
gmt pscoast -R -J -W0.6p,black -N1/0.4p,gray30 -O -K >> "${ps_file}"
printf "%s %s\n%s %s\n" -130 "${section_latitude}" -116 \
	"${section_latitude}" | gmt psxy -R -J -W${profile_pen} -O -K >> "${ps_file}"
gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-2.65i/-0.55i+w5.3i/0.13i+h \
	-Bxa1f0.5+l"Vs (km/s)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/cascadia_vs_slices"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/cascadia_vs_slices"

section_region=-130/-116/-5/60
section_projection=X2.3i/-1.7i
section_ps="${work_dir}/cascadia_vs_vertical_slices.ps"

gmt grdimage "${delph_vertical}" -P -R${section_region} \
	-J${section_projection} -C"${velocity_cpt}" -Bxa5f1+l"Longitude" \
	-Bya10f5+l"Depth (km)" -BWSen+t"(a) Cascadia ANT+RF" \
	-fc -X0.45i -Y4.1i -K > "${section_ps}"

gmt grdimage "${porritt_vertical}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya10f5 -BwSen+t"(b) PNW10-S" \
	-fc -X2.65i -O -K >> "${section_ps}"

gmt grdimage "${savard_vertical}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya10f5 -BwSen+t"(c) SVI EQTOMO" \
	-fc -X2.65i -O -K >> "${section_ps}"

gmt grdimage "${wus324_vertical}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya10f5+l"Depth (km)" \
	-BWSen+t"(d) WUS324 Cascadia" -fc -X-3.975i -Y-2.9i \
	-O -K >> "${section_ps}"

gmt grdimage "${casc16_vertical}" -R -J -C"${velocity_cpt}" \
	-Bxa5f1+l"Longitude" -Bya10f5 -BwSen+t"(e) Cascadia v1.6" \
	-fc -X2.65i -O -K >> "${section_ps}"

gmt psscale -R -J -C"${velocity_cpt}" \
	-Dx-2.65i/-0.75i+w5.3i/0.13i+h \
	-Bxa1f0.5+l"Vs (km/s)" --FONT_ANNOT_PRIMARY=${colorbar_font} \
	--FONT_LABEL=${colorbar_font} -O >> "${section_ps}"

gmt psconvert "${section_ps}" -A -Tf \
	-F"${script_dir}/cascadia_vs_vertical_slices"
gmt psconvert "${section_ps}" -A -Tg -E300 \
	-F"${script_dir}/cascadia_vs_vertical_slices"
