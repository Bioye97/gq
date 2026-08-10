#!/usr/bin/env bash
#
# Download the public Cascadia models and cache their horizontal and vertical
# parameter slices.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
curl_executable=${CURL:-$(command -v curl || true)}
if [[ -z "${curl_executable}" ]]; then
	echo "curl was not found; set CURL=/path/to/curl" >&2
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
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-cascadia-slices.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
mkdir -p "${data_dir}"

download_model() {
	local filename=$1
	local metadata=$2
	local output="${data_dir}/${filename}"
	local partial="${output}.part"
	if [[ -s "${output}" ]]; then
		return
	fi
	echo "Downloading ${filename}" >&2
	"${curl_executable}" -L --fail --retry 3 --continue-at - \
		--output "${partial}" \
		"https://cvm.cascadiaquakes.org/data/download-netcdf-s3/?filename=${metadata}"
	mv "${partial}" "${output}"
}

download_model "Cascadia-ANT+RF-Delph2018.r0.1.nc" \
	"Cascadia-ANT%2BRF-Delph2018.r0.1.json"
download_model "PNW10-S_CVM.r0.1.nc" "PNW10-S_CVM.r0.1.json"
download_model "SVI_EQTOMO_Savard2018.r0.1.nc" \
	"SVI_EQTOMO_Savard2018.r0.1.json"
download_model "WUS324-Casc-CVM.r0.0-n4.nc" \
	"WUS324-Casc-CVM.r0.0-n4.json"
download_model "casc1.6-velmdl.r1.0-n4.nc" \
	"casc1.6-velmdl.r1.0-n4.json"

delph="${data_dir}/Cascadia-ANT+RF-Delph2018.r0.1.nc"
porritt="${data_dir}/PNW10-S_CVM.r0.1.nc"
savard="${data_dir}/SVI_EQTOMO_Savard2018.r0.1.nc"
wus324="${data_dir}/WUS324-Casc-CVM.r0.0-n4.nc"
casc16="${data_dir}/casc1.6-velmdl.r1.0-n4.nc"

delph_slice="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-2km.nc"
porritt_slice="${data_dir}/PNW10-S-Vs-2km.nc"
savard_slice="${data_dir}/SVI-EQTOMO-Savard2018-Vs-2km.nc"
savard_vp_slice="${data_dir}/SVI-EQTOMO-Savard2018-Vp-2km.nc"
savard_density_slice="${data_dir}/SVI-EQTOMO-Savard2018-Density-2km.nc"
wus324_slice="${data_dir}/WUS324-Casc-Vs-2km.nc"
wus324_vp_slice="${data_dir}/WUS324-Casc-Vp-2km.nc"
wus324_density_slice="${data_dir}/WUS324-Casc-Density-2km.nc"
casc16_slice="${data_dir}/casc1.6-velmdl-Vs-2km.nc"
casc16_vp_slice="${data_dir}/casc1.6-velmdl-Vp-2km.nc"
delph_vertical="${data_dir}/Cascadia-ANT+RF-Delph2018-Vs-lat47.nc"
porritt_vertical="${data_dir}/PNW10-S-Vs-lat47.nc"
savard_vertical="${data_dir}/SVI-EQTOMO-Savard2018-Vs-lat47.nc"
wus324_vertical="${data_dir}/WUS324-Casc-Vs-lat47.nc"
casc16_vertical="${data_dir}/casc1.6-velmdl-Vs-lat47.nc"

if [[ ! -s "${delph_slice}" ]]; then
	gmt grdconvert "${delph}?Vs[5]" "${work_dir}/delph.nc"
	mv "${work_dir}/delph.nc" "${delph_slice}"
fi
if [[ ! -s "${porritt_slice}" ]]; then
	gmt grdmath "${porritt}?Vs[0]" 0.2 MUL "${porritt}?Vs[1]" 0.8 MUL \
		ADD = "${work_dir}/porritt.nc"
	mv "${work_dir}/porritt.nc" "${porritt_slice}"
fi
if [[ ! -s "${savard_slice}" ]]; then
	gmt grdmath "${savard}?Vs[0]" 0.3333333333333333 MUL \
		"${savard}?Vs[1]" 0.6666666666666667 MUL \
		ADD = "${work_dir}/savard.nc"
	mv "${work_dir}/savard.nc" "${savard_slice}"
fi
if [[ ! -s "${savard_vp_slice}" ]]; then
	gmt grdmath "${savard}?Vp[0]" 0.3333333333333333 MUL \
		"${savard}?Vp[1]" 0.6666666666666667 MUL \
		ADD = "${work_dir}/savard_vp.nc"
	mv "${work_dir}/savard_vp.nc" "${savard_vp_slice}"
fi
if [[ ! -s "${savard_density_slice}" ]]; then
	gmt grdmath "${savard}?Density[0]" 0.3333333333333333 MUL \
		"${savard}?Density[1]" 0.6666666666666667 MUL \
		ADD = "${work_dir}/savard_density.nc"
	mv "${work_dir}/savard_density.nc" "${savard_density_slice}"
fi
if [[ ! -s "${wus324_slice}" ]]; then
	gmt grdconvert "${wus324}?Vs[6]" "${work_dir}/wus324.nc"
	mv "${work_dir}/wus324.nc" "${wus324_slice}"
fi
if [[ ! -s "${wus324_vp_slice}" ]]; then
	gmt grdconvert "${wus324}?Vp[6]" "${work_dir}/wus324_vp.nc"
	mv "${work_dir}/wus324_vp.nc" "${wus324_vp_slice}"
fi
if [[ ! -s "${wus324_density_slice}" ]]; then
	gmt grdconvert "${wus324}?Density[6]+s0.001" \
		"${work_dir}/wus324_density.nc"
	mv "${work_dir}/wus324_density.nc" "${wus324_density_slice}"
fi
if [[ ! -s "${casc16_slice}" ]]; then
	gmt grdconvert "${casc16}?Vs[4]+s0.001" "${work_dir}/casc16_utm.nc"
	gmt grdproject "${work_dir}/casc16_utm.nc" \
		-G"${work_dir}/casc16.nc" -Ju10N/1:1 -I -C -Fe -D0.02 -nl+c
	mv "${work_dir}/casc16.nc" "${casc16_slice}"
fi
if [[ ! -s "${casc16_vp_slice}" ]]; then
	gmt grdconvert "${casc16}?Vp[4]+s0.001" "${work_dir}/casc16_vp_utm.nc"
	gmt grdproject "${work_dir}/casc16_vp_utm.nc" \
		-G"${work_dir}/casc16_vp.nc" -Ju10N/1:1 -I -C -Fe -D0.02 -nl+c
	mv "${work_dir}/casc16_vp.nc" "${casc16_vp_slice}"
fi

prepare_geographic_vertical() {
	local source=$1
	local west=$2
	local east=$3
	local top=$4
	local output=$5
	local temporary="${work_dir}/$(basename "${output}")"
	local native="${temporary%.nc}-native.nc"
	if vertical_is_current "${output}"; then
		return
	fi
	gmt grdinterpolate "${source}" \
		-E${west}/47/${east}/47+g -T${top}/60/1 -Fl -G"${native}"
	gmt grdcut "${native}" -R${west}/${east}/-5/60 -NNaN \
		-G"${temporary}"
	mv "${temporary}" "${output}"
}

vertical_is_current() {
	local section=$1
	[[ -s "${section}" ]] &&
		gmt grdinfo -C "${section}" | awk '{exit !($4 <= -5)}'
}

prepare_geographic_vertical "${delph}?Vs" -124.9 -119.9 -3 \
	"${delph_vertical}"
prepare_geographic_vertical "${porritt}?Vs" -124.25 -118.95 0 \
	"${porritt_vertical}"
prepare_geographic_vertical "${savard}?Vs" -126 -121.1 0 \
	"${savard_vertical}"
prepare_geographic_vertical "${wus324}?Vs" -130 -116 -4 \
	"${wus324_vertical}"

# Cascadia v1.6 is stored in UTM Zone 10 coordinates and meters. Project the
# latitude = 47 N profile before sampling every native 1 km depth level.
if ! vertical_is_current "${casc16_vertical}"; then
	profile_geo="${work_dir}/casc16_profile_geo.txt"
	profile_utm="${work_dir}/casc16_profile_utm.txt"
	section_xyz="${work_dir}/casc16_vertical.xyz"
	awk 'BEGIN {
		for (i = 0; i <= 79; i++) {
			longitude = -129 + 0.1 * i
			printf "%.10g 47 %.10g\n", longitude, longitude
		}
	}' > "${profile_geo}"
	gmt mapproject "${profile_geo}" -Ju10N/1:1 -C -Fe > "${profile_utm}"
	: > "${section_xyz}"
	for depth in $(seq 0 60); do
		level=$((2 * depth))
		gmt grdtrack "${profile_utm}" -G"${casc16}?Vs[${level}]" \
			-nl -Vq | awk -v depth="${depth}" '
			$4 != "NaN" {print $3, depth, 0.001 * $4}
		' >> "${section_xyz}"
	done
	gmt xyz2grd "${section_xyz}" -R-129/-121.1/-5/60 -I0.1/1 \
		-G"${work_dir}/casc16_vertical.nc"
	mv "${work_dir}/casc16_vertical.nc" "${casc16_vertical}"
fi

printf "Cascadia model slices are cached in %s\n" "${data_dir}"
