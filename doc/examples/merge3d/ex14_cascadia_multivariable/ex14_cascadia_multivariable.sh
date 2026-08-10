#!/usr/bin/env bash
#
# Merge full-volume Cascadia Vp, Vs, and density fields together.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
ncdump_executable=${NCDUMP:-$(command -v ncdump || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
if [[ -z "${ncdump_executable}" ]]; then
	echo "ncdump was not found; set NCDUMP=/path/to/ncdump" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prepare_script="${script_dir}/../../data/cascadia/prepare_vs_slices.sh"
if [[ -n "${GQ_EXAMPLE_DATA:-}" ]]; then
	data_dir="${GQ_EXAMPLE_DATA}/cascadia"
else
	data_dir="${script_dir}/../../data/cascadia"
fi
GMT="${gmt_executable}" "${prepare_script}"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-merge3d-ex14-cascadia.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

# The WUS324 density scale converts kg/m3 to g/cm3. Target-unit modifiers make
# all output metadata explicit and consistent across the two source models.
svi="${data_dir}/SVI_EQTOMO_Savard2018.r0.1.nc?Vp,Vs,Density+Vkm/s,km/s,g/cm3"
wus324="${data_dir}/WUS324-Casc-CVM.r0.0-n4.nc?Vp,Vs,Density+v1,1,0.001+Vkm/s,km/s,g/cm3"
region=-130/-116/39/52
increment=0.05
zrange=0/60/1
section_depth=2
section_latitude=47
section_region=-130/-116/0/60
map_projection=M2.2i
vertical_projection=X2.2i/-1.7i
taper_ratios=0.2/0.2/0.2/0.2/0/0.2
mergefile="${work_dir}/multivariable.merge3d"
tiled="${work_dir}/tiled.nc"
aggregate="${work_dir}/aggregate.nc"
vp_cpt="${work_dir}/vp.cpt"
vs_cpt="${work_dir}/vs.cpt"
density_cpt="${work_dir}/density.cpt"
colorbar_font=18.1p

gmt merge3d "${svi}" "${wus324}" -R${region} -I${increment} \
	-T${zrange} -Cf -Fvp,vs,density -G"${tiled}"
cat > "${mergefile}" <<- EOF
	${svi} ${wus324} - - cosine/cosine/cosine ${taper_ratios}
	${wus324} - - - - -
	EOF
gmt merge3d "${mergefile}" -R${region} -I${increment} -T${zrange} \
	-A -P -Fvp,vs,density -G"${aggregate}"

# Confirm field names and standardized unit metadata in both outputs.
for output in "${tiled}" "${aggregate}"; do
	"${ncdump_executable}" -h "${output}" > "${output}.header"
	for field in vp vs density; do
		grep -Eq "(float|double) ${field}\\(" "${output}.header"
	done
	grep -q 'vp:units = "km/s"' "${output}.header"
	grep -q 'vs:units = "km/s"' "${output}.header"
	grep -q 'density:units = "g/cm3"' "${output}.header"
done

for field in vp vs density; do
	for name in tiled aggregate; do
		gmt grdconvert "${work_dir}/${name}.nc?${field}[${section_depth}]" \
			"${work_dir}/${name}_${field}_horizontal.nc"
		gmt grdcut "${work_dir}/${name}.nc?${field}" -Ey${section_latitude} \
			-G"${work_dir}/${name}_${field}_vertical.nc"
	done
	for view in horizontal vertical; do
		gmt grdmath "${work_dir}/aggregate_${field}_${view}.nc" \
			"${work_dir}/tiled_${field}_${view}.nc" SUB = \
			"${work_dir}/${field}_${view}_difference.nc"
		gmt grdinfo "${work_dir}/${field}_${view}_difference.nc" -C | \
			awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'
	done
done

gmt set FONT_ANNOT_PRIMARY 9p FONT_LABEL 10p FONT_TITLE 10p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 12p COLOR_NAN white
gmt makecpt -Cturbo -T1.5/9/0.25 -Z > "${vp_cpt}"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${vs_cpt}"
gmt makecpt -Cturbo -T2.3/3.5/0.05 -Z > "${density_cpt}"

fields=(vp vs density vp vs density)
states=(tiled tiled tiled aggregate aggregate aggregate)
titles=("Vp tiling" "Vs tiling" "Density tiling" \
	"Vp aggregate" "Vs aggregate" "Density aggregate")
letters=(a b c d e f)

field_cpt() {
	case $1 in
		vp) printf "%s" "${vp_cpt}" ;;
		vs) printf "%s" "${vs_cpt}" ;;
		density) printf "%s" "${density_cpt}" ;;
	esac
}

field_scale() {
	case $1 in
		vp) printf "%s" '-Bxa2f1+lVp (km/s)' ;;
		vs) printf "%s" '-Bxa1f0.5+lVs (km/s)' ;;
		density) printf "%s" '-Bxa0.2f0.1+lDensity (g/cm@+3@+)' ;;
	esac
}

plot_horizontal() {
	local ps_file="${work_dir}/ex14_horizontal.ps"
	for index in 0 1 2 3 4 5; do
		field=${fields[index]}
		state=${states[index]}
		cpt=$(field_cpt "${field}")
		title="(${letters[index]}) ${titles[index]}: z = ${section_depth} km"
		y_axis=-Bya5f1
		x_axis=-Bxa5f1
		if ((index == 0 || index == 3)); then y_axis=-Bya5f1+l"Latitude"; fi
		if ((index >= 3)); then x_axis=-Bxa5f1+l"Longitude"; fi
		if ((index == 0)); then
			gmt grdimage "${work_dir}/${state}_${field}_horizontal.nc" -P \
				-R${region} -J${map_projection} -C"${cpt}" "${x_axis}" \
				"${y_axis}" "-BWSen+t${title}" -X0.45i -Y5.4i -K > "${ps_file}"
		elif ((index == 3)); then
			gmt grdimage "${work_dir}/${state}_${field}_horizontal.nc" \
				-R -J -C"${cpt}" "${x_axis}" "${y_axis}" \
				"-BWSen+t${title}" -X-5.5i -Y-3.95i -O -K >> "${ps_file}"
		else
			gmt grdimage "${work_dir}/${state}_${field}_horizontal.nc" \
				-R -J -C"${cpt}" "${x_axis}" "${y_axis}" \
				"-BWSen+t${title}" -X2.75i -O -K >> "${ps_file}"
		fi
		gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps_file}"
		printf "%s %s\n%s %s\n" -130 "${section_latitude}" -116 "${section_latitude}" | \
			gmt psxy -R -J -W1.5p,black,-- -O -K >> "${ps_file}"
		if ((index >= 3)); then
			scale=$(field_scale "${field}")
			gmt psscale -R -J -C"${cpt}" -DjBC+w1.8i/0.1i+h+o0/-0.75i \
				"${scale}" --FONT_ANNOT_PRIMARY=${colorbar_font} \
				--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"
		fi
	done
	# Close the PostScript stream after the final colorbar.
	gmt psxy -R -J -T -O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tf \
		-F"${script_dir}/ex14_cascadia_multivariable_horizontal"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/ex14_cascadia_multivariable_horizontal"
}

plot_vertical() {
	local ps_file="${work_dir}/ex14_vertical.ps"
	for index in 0 1 2 3 4 5; do
		field=${fields[index]}
		state=${states[index]}
		cpt=$(field_cpt "${field}")
		title="(${letters[index]}) ${titles[index]}: latitude = ${section_latitude} N"
		y_axis=-Bya20f10
		x_axis=-Bxa5f1
		if ((index == 0 || index == 3)); then y_axis=-Bya20f10+l"Depth (km)"; fi
		if ((index >= 3)); then x_axis=-Bxa5f1+l"Longitude"; fi
		if ((index == 0)); then
			gmt grdimage "${work_dir}/${state}_${field}_vertical.nc" -P \
				-R${section_region} -J${vertical_projection} -C"${cpt}" \
				"${x_axis}" "${y_axis}" "-BWSen+t${title}" -fc \
				-X0.45i -Y5.2i -K > "${ps_file}"
		elif ((index == 3)); then
			gmt grdimage "${work_dir}/${state}_${field}_vertical.nc" \
				-R -J -C"${cpt}" "${x_axis}" "${y_axis}" \
				"-BWSen+t${title}" -fc -X-5.5i -Y-2.95i -O -K >> "${ps_file}"
		else
			gmt grdimage "${work_dir}/${state}_${field}_vertical.nc" \
				-R -J -C"${cpt}" "${x_axis}" "${y_axis}" \
				"-BWSen+t${title}" -fc -X2.75i -O -K >> "${ps_file}"
		fi
		printf "%s %s\n%s %s\n" -130 "${section_depth}" -116 "${section_depth}" | \
			gmt psxy -R -J -W1.5p,black,-- -fc -O -K >> "${ps_file}"
		if ((index >= 3)); then
			scale=$(field_scale "${field}")
			gmt psscale -R -J -C"${cpt}" -DjBC+w1.8i/0.1i+h+o0/-1.1i \
				"${scale}" --FONT_ANNOT_PRIMARY=${colorbar_font} \
				--FONT_LABEL=${colorbar_font} -O -K >> "${ps_file}"
		fi
	done
	gmt psxy -R -J -T -O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A+m0.1i -Tf \
		-F"${script_dir}/ex14_cascadia_multivariable_vertical"
	gmt psconvert "${ps_file}" -A+m0.1i -Tg -E300 \
		-F"${script_dir}/ex14_cascadia_multivariable_vertical"
}

plot_horizontal
plot_vertical
