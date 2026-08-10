#!/usr/bin/env bash
#
# Apply ssh3d heterogeneities to three Cascadia velocity models.

set -euo pipefail
gmt_executable=${GMT:-$(command -v gmt || true)}
ncgen_executable=${NCGEN:-$(command -v ncgen || true)}
[[ -n "${gmt_executable}" ]] || { echo "GMT was not found; set GMT=/path/to/gmt" >&2; exit 1; }
[[ -n "${ncgen_executable}" ]] || { echo "ncgen was not found; set NCGEN=/path/to/ncgen" >&2; exit 1; }
gmt() { command "${gmt_executable}" "$@"; }
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prepare_script="${script_dir}/../../data/cascadia/prepare_vs_slices.sh"
if [[ -n "${GQ_EXAMPLE_DATA:-}" ]]; then
	data_dir="${GQ_EXAMPLE_DATA}/cascadia"
else
	data_dir="${script_dir}/../../data/cascadia"
fi
GMT="${gmt_executable}" "${prepare_script}"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh3d-ex05.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"
gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

models=(
	"${data_dir}/Cascadia-ANT+RF-Delph2018.r0.1.nc"
	"${data_dir}/PNW10-S_CVM.r0.1.nc"
	"${data_dir}/SVI_EQTOMO_Savard2018.r0.1.nc"
	"${data_dir}/WUS324-Casc-CVM.r0.0-n4.nc"
	"${data_dir}/casc1.6-velmdl-Vs-10km-2km.nc"
)
names=(ant_rf pnw10_s svi_eqtomo wus324 cascadia_v16)
titles=("Cascadia ANT+RF" "PNW10-S" "SVI EQTOMO" "WUS324 Cascadia" "Cascadia v1.6")
fields=(Vs Vs Vs cube Vs)
original_maps=(
	"${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
	"${data_dir}/PNW10-S-Vs-2km.nc"
	"${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
	"${data_dir}/WUS324-Casc-Vs-2km.nc"
	"${data_dir}/casc1.6-velmdl-Vs-2km.nc"
)
original_sections=(
	"${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-lat47.nc"
	"${data_dir}/PNW10-S-Vs-lat47.nc"
	"${data_dir}/SVI-EQTOMO-Savard2018-Vs-lat47.nc"
	"${data_dir}/WUS324-Casc-Vs-lat47.nc"
	"${data_dir}/casc1.6-velmdl-Vs-lat47.nc"
)
profile_latitude=47
profile_pen=1.5p,black,--

# Build a compact working cube before ssh3d reads the large Cascadia v1.6
# model. The cache retains the full horizontal domain and 0-60 km volume.
prepare_cascadia_v16_volume() {
	local source="${data_dir}/casc1.6-velmdl.r1.0-n4.nc"
	local output="${models[4]}"
	local cdl="${work_dir}/cascadia_v16_reduced.cdl"
	local layer="${work_dir}/cascadia_v16_layer.nc"
	local sampled="${work_dir}/cascadia_v16_sampled.nc"
	local nx ny depth index first=1
	[[ -s "${output}" ]] && return

	gmt grdconvert "${source}?Vs[0]+s0.001" "${layer}"
	gmt grdsample "${layer}" -I10000+e -nl -G"${sampled}"
	nx=$(gmt grd2xyz "${sampled}" | awk '{print $1}' | sort -nu | wc -l | tr -d ' ')
	ny=$(gmt grd2xyz "${sampled}" | awk '{print $2}' | sort -nu | wc -l | tr -d ' ')
	cat > "${cdl}" <<- EOF
		netcdf cascadia_v16_reduced {
		dimensions: depth = 31 ; y = ${ny} ; x = ${nx} ;
		variables:
			double depth(depth) ; depth:axis = "Z" ; depth:units = "km" ; depth:positive = "down" ;
			double y(y) ; y:axis = "Y" ; y:units = "m" ;
			double x(x) ; x:axis = "X" ; x:units = "m" ;
			float Vs(depth, y, x) ; Vs:_FillValue = NaNf ; Vs:units = "km/s" ;
		data:
		EOF
	gmt grd2xyz "${sampled}" | awk '{print $1}' | sort -nu | \
		awk 'BEGIN {printf "\tx = "} {printf "%s%.17g", (NR == 1 ? "" : ", "), $1} END {print " ;"}' >> "${cdl}"
	gmt grd2xyz "${sampled}" | awk '{print $2}' | sort -nu | \
		awk 'BEGIN {printf "\ty = "} {printf "%s%.17g", (NR == 1 ? "" : ", "), $1} END {print " ;"}' >> "${cdl}"
	awk 'BEGIN {printf "\tdepth = "; for (d = 0; d <= 60; d += 2) printf "%s%d", (d ? ", " : ""), d; print " ;"}' >> "${cdl}"
	printf '\tVs = ' >> "${cdl}"
	for depth in $(seq 0 2 60); do
		index=$((2 * depth))
		gmt grdconvert "${source}?Vs[${index}]+s0.001" "${layer}"
		gmt grdsample "${layer}" -I10000+e -nl -G"${sampled}"
		gmt grd2xyz "${sampled}" -ZBL | awk -v first="${first}" '
		{
			value = ($1 == "NaN" || $1 == "nan") ? "_" : $1
			printf "%s%s", (first && NR == 1) ? "" : ", ", value
			if (NR % 8 == 0) printf "\n\t\t"
		}' >> "${cdl}"
		first=0
	done
	printf ' ;\n}\n' >> "${cdl}"
	"${ncgen_executable}" -o "${work_dir}/cascadia_v16_reduced.nc" "${cdl}"
	mv "${work_dir}/cascadia_v16_reduced.nc" "${output}"
}

prepare_cascadia_v16_volume

# WUS324 changes from 1 km to 5 km depth spacing below 60 km. Prepare the
# regular interval used by this example before ssh3d validates the z axis.
gmt grdinterpolate "${models[3]}?Vs" -T0/60/2 -Fl \
	-G"${work_dir}/wus324_0_60.nc"
models[3]="${work_dir}/wus324_0_60.nc"

perturbed_maps=()
perturbed_sections=()
for ((i=0; i<5; i++)); do
	output="${work_dir}/${names[i]}_perturbed.nc"
	correlation=0.5/0.3/5
	if ((i==4)); then correlation=50000/30000/5; fi
	gmt ssh3d "${models[i]}" -A -F"${fields[i]}" -D0.04 -C"${correlation}" -U0.3 \
		-T0/60/2 -Q$((101+i)) -G"${output}"
	if ((i<4)); then
		perturbed_maps[i]="${work_dir}/${names[i]}_perturbed_map.nc"
		perturbed_sections[i]="${work_dir}/${names[i]}_perturbed_section.nc"
		gmt grdconvert "${output}?${fields[i]}[1]" "${perturbed_maps[i]}"
		gmt grdcut "${output}?${fields[i]}" -Ey"${profile_latitude}" \
			-G"${perturbed_sections[i]}"
	fi
done

# Convert the downsampled UTM output for Cascadia v1.6 to geographic map and
# latitude = 47 degree section grids.
perturbed_maps[4]="${work_dir}/cascadia_v16_perturbed_map.nc"
perturbed_sections[4]="${work_dir}/cascadia_v16_perturbed_section.nc"
gmt grdconvert "${work_dir}/cascadia_v16_perturbed.nc?Vs[1]" \
	"${work_dir}/cascadia_v16_perturbed_utm.nc"
gmt grdproject "${work_dir}/cascadia_v16_perturbed_utm.nc" \
	-G"${perturbed_maps[4]}" -Ju10N/1:1 -I -C -Fe -D0.1 -nl+c
profile_geo="${work_dir}/cascadia_v16_profile_geo.txt"
profile_utm="${work_dir}/cascadia_v16_profile_utm.txt"
section_xyz="${work_dir}/cascadia_v16_perturbed.xyz"
awk -v latitude="${profile_latitude}" 'BEGIN {
	for (longitude = -130; longitude <= -116.0001; longitude += 0.1)
		printf "%.10g %.10g %.10g\n", longitude, latitude, longitude
}' > "${profile_geo}"
gmt mapproject "${profile_geo}" -Ju10N/1:1 -C -Fe > "${profile_utm}"
: > "${section_xyz}"
for ((level=0; level<=30; level++)); do
	depth=$((2 * level))
	gmt grdtrack "${profile_utm}" \
		-G"${work_dir}/cascadia_v16_perturbed.nc?Vs[${level}]" -nl -Vq | \
		awk -v depth="${depth}" '$4 != "NaN" {print $3, depth, $4}' \
		>> "${section_xyz}"
done
gmt xyz2grd "${section_xyz}" -R-130/-116/0/60 -I0.1/2 \
	-G"${perturbed_sections[4]}"

gmt makecpt -Cturbo -T0/5.5/0.1 -Z > "${work_dir}/velocity.cpt"

letters=(a b c d e)
map_region=-130/-116/39/52
map_projection=M2.3i
section_region=-130/-116/0/60
section_projection=X2.3i/-1.7i
colorbar_font=10.6p

plot_maps() {
	local state=$1 output_name=$2 state_label=$3
	local ps_file="${work_dir}/${output_name}.ps"
	local grid shift xaxis yaxis frame
	for ((i=0; i<5; i++)); do
		grid="${original_maps[i]}"
		[[ ${state} == perturbed ]] && grid="${perturbed_maps[i]}"
		shift=(-X2.65i)
		((i==0)) && shift=(-X0.45i -Y5.3i)
		((i==3)) && shift=(-X-3.975i -Y-4.1i)
		xaxis=-Bxa5f1; yaxis=-Bya5f1; frame=-BwSen
		if ((i==0)); then yaxis=-Bya5f1+lLatitude; frame=-BWSen; fi
		if ((i==3)); then xaxis=-Bxa5f1+lLongitude; yaxis=-Bya5f1+lLatitude; frame=-BWSen; fi
		if ((i==4)); then xaxis=-Bxa5f1+lLongitude; fi
		if ((i==0)); then
			gmt grdimage "${grid}" -P -R${map_region} -J${map_projection} \
				-C"${work_dir}/velocity.cpt" "${xaxis}" "${yaxis}" \
				${frame}+t"(${letters[i]}) ${titles[i]}: ${state_label}" \
				"${shift[@]}" -K > "${ps_file}"
		else
			gmt grdimage "${grid}" -R${map_region} -J${map_projection} \
				-C"${work_dir}/velocity.cpt" "${xaxis}" "${yaxis}" \
				${frame}+t"(${letters[i]}) ${titles[i]}: ${state_label}" \
				"${shift[@]}" -O -K >> "${ps_file}"
		fi
		gmt pscoast -R -J -W0.6p,black -N1/0.4p,gray30 -O -K >> "${ps_file}"
		printf '%s %s\n%s %s\n' -130 "${profile_latitude}" -116 \
			"${profile_latitude}" | gmt psxy -R -J -W${profile_pen} -fg -O -K >> "${ps_file}"
		printf '%s\n' '-116.25 39.3 2 km' | \
			gmt pstext -R -J -F+f10p,Helvetica,black+jBR -Gwhite -C0.06c -O -K >> "${ps_file}"
	done
	gmt psscale -R -J -C"${work_dir}/velocity.cpt" \
		-Dx-2.65i/-0.55i+w5.3i/0.13i+h -Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} -O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/${output_name}"
	gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/${output_name}"
}

plot_sections() {
	local state=$1 output_name=$2 state_label=$3
	local ps_file="${work_dir}/${output_name}.ps"
	local grid shift yaxis frame
	for ((i=0; i<5; i++)); do
		grid="${original_sections[i]}"
		[[ ${state} == perturbed ]] && grid="${perturbed_sections[i]}"
		shift=(-X2.65i)
		((i==0)) && shift=(-X0.45i -Y4.3i)
		((i==3)) && shift=(-X-3.975i -Y-3.1i)
		yaxis=-Bya10f5; frame=-BwSen
		if ((i==0 || i==3)); then yaxis=-Bya10f5+l"Depth (km)"; frame=-BWSen; fi
		if ((i==0)); then
			gmt grdimage "${grid}" -P -R${section_region} -J${section_projection} \
				-C"${work_dir}/velocity.cpt" -Bxa5f1+lLongitude "${yaxis}" \
				${frame}+t"(${letters[i]}) ${titles[i]}: ${state_label}" \
				-fc "${shift[@]}" -K > "${ps_file}"
		else
			gmt grdimage "${grid}" -R${section_region} -J${section_projection} \
				-C"${work_dir}/velocity.cpt" -Bxa5f1+lLongitude "${yaxis}" \
				${frame}+t"(${letters[i]}) ${titles[i]}: ${state_label}" \
				-fc "${shift[@]}" -O -K >> "${ps_file}"
		fi
	done
	gmt psscale -R -J -C"${work_dir}/velocity.cpt" \
		-Dx-2.65i/-0.75i+w5.3i/0.13i+h -Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} --FONT_LABEL=${colorbar_font} -O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/${output_name}"
	gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/${output_name}"
}

plot_maps original ex05_cascadia_models_original_maps Original
plot_maps perturbed ex05_cascadia_models_perturbed_maps Perturbed
plot_sections original ex05_cascadia_models_original_sections Original
plot_sections perturbed ex05_cascadia_models_perturbed_sections Perturbed
