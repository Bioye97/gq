#!/usr/bin/env bash
#
# Add two-dimensional heterogeneities to extracted Cascadia Vs slices.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() { command "${gmt_executable}" "$@"; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
data_dir="${script_dir}/../../data/cascadia"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ssh2d-ex11.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p COLOR_NAN white

models=(
	"${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
	"${data_dir}/PNW10-S-Vs-2km.nc"
	"${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
	"${data_dir}/WUS324-Casc-Vs-2km.nc"
	"${data_dir}/casc1.6-velmdl-Vs-2km.nc"
)
names=(ant_rf pnw10_s svi_eqtomo wus324 cascadia_v16)
fields=(Vs Vs Vs Vs z)
titles=("Cascadia ANT+RF" "PNW10-S" "SVI EQTOMO" "WUS324 Cascadia" "Cascadia v1.6")
regions=(
	-124.9/-119.9/39.9/49.1
	-124.25/-119.05/38.15/49.05
	-126/-121.1/47/50.9
	-130/-116/39/52
	-130.104/-121.018/40.198/50.0171
)

for ((index=0; index<5; index++)); do
	gmt ssh2d "${models[index]}" -A -F"${fields[index]}" -D0.04 -C0.5/0.3 -U0.3 \
		-Q$((101 + index)) -G"${work_dir}/${names[index]}_perturbed.nc"
done
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${work_dir}/velocity.cpt"

letters=(a b c d e)
region=-130/-116/39/52
projection=M2.3i
colorbar_font=10.6p

plot_state() {
	local state=$1 output_name=$2 state_label=$3
	local ps_file="${work_dir}/${output_name}.ps"
	local grid shift xaxis yaxis frame

	for ((index=0; index<5; index++)); do
		grid="${models[index]}?${fields[index]}"
		if [[ "${state}" == perturbed ]]; then
			grid="${work_dir}/${names[index]}_perturbed.nc?${fields[index]}"
		fi

		shift=(-X2.65i)
		if ((index==0)); then shift=(-X0.45i -Y5.3i); fi
		if ((index==3)); then shift=(-X-3.975i -Y-4.1i); fi

		xaxis=-Bxa5f1
		yaxis=-Bya5f1
		frame=-BwSen
		if ((index==0)); then
			yaxis=-Bya5f1+l"Latitude"
			frame=-BWSen
		fi
		if ((index==3)); then
			xaxis=-Bxa5f1+l"Longitude"
			yaxis=-Bya5f1+l"Latitude"
			frame=-BWSen
		fi
		if ((index==4)); then xaxis=-Bxa5f1+l"Longitude"; fi

		if ((index==0)); then
			gmt grdimage "${grid}" -P -R${region} -J${projection} \
				-C"${work_dir}/velocity.cpt" "${xaxis}" "${yaxis}" \
				${frame}+t"(${letters[index]}) ${titles[index]}: ${state_label}" \
				"${shift[@]}" -K > "${ps_file}"
		else
			gmt grdimage "${grid}" -R${region} -J${projection} \
				-C"${work_dir}/velocity.cpt" "${xaxis}" "${yaxis}" \
				${frame}+t"(${letters[index]}) ${titles[index]}: ${state_label}" \
				"${shift[@]}" -O -K >> "${ps_file}"
		fi
		gmt pscoast -R -J -W0.6p,black -N1/0.4p,gray30 -O -K >> "${ps_file}"
		printf '%s\n' '-116.25 39.3 2 km' | \
			gmt pstext -R -J -F+f10p,Helvetica,black+jBR \
				-Gwhite -C0.06c -O -K >> "${ps_file}"
	done

	gmt psscale -R -J -C"${work_dir}/velocity.cpt" \
		-Dx-2.65i/-0.55i+w5.3i/0.13i+h \
		-Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${colorbar_font} \
		--FONT_LABEL=${colorbar_font} -O >> "${ps_file}"
	gmt psconvert "${ps_file}" -A -Tf -F"${script_dir}/${output_name}"
	gmt psconvert "${ps_file}" -A -Tg -E300 -F"${script_dir}/${output_name}"
}

plot_state original ex11_cascadia_slices_original Original
plot_state perturbed ex11_cascadia_slices_perturbed Perturbed
