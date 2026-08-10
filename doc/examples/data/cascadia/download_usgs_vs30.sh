#!/usr/bin/env bash
#
# Download a server-side Cascadia crop of the USGS Global Hybrid Vs30 Mosaic.

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
output="${data_dir}/USGS_global_vs30_cascadia.nc"
if [[ -s "${output}" ]]; then
	printf 'USGS Cascadia Vs30 is already cached in %s\n' "${output}"
	exit 0
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-usgs-vs30.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
mkdir -p "${data_dir}"

service='https://earthquake.usgs.gov/arcgis/rest/services/gp/VS30_extract/GPServer/Extract%20Data/execute'
area='{"geometryType":"esriGeometryPolygon","spatialReference":{"wkid":4326},"fields":[{"name":"OBJECTID","type":"esriFieldTypeOID","alias":"OBJECTID"},{"name":"Id","type":"esriFieldTypeInteger","alias":"Id"}],"features":[{"geometry":{"rings":[[[-130,39],[-116,39],[-116,52],[-130,52],[-130,39]]],"spatialReference":{"wkid":4326}},"attributes":{"OBJECTID":1,"Id":1}}]}'

response=$("${curl_executable}" -sS --fail -X POST "${service}" \
	--data-urlencode 'f=json' \
	--data-urlencode 'Layers_to_Clip=["vs30_mosaic"]' \
	--data-urlencode "Area_of_Interest=${area}" \
	--data-urlencode 'Feature_Format=File Geodatabase - GDB - .gdb' \
	--data-urlencode 'Raster_Format=Tagged Image File Format - TIFF - .tif' \
	--data-urlencode 'Spatial_Reference=4326')
url=$(printf '%s\n' "${response}" | \
	sed -n 's/.*"url":"\([^"]*\)".*/\1/p')
if [[ -z "${url}" ]]; then
	echo "USGS Vs30 extraction did not return a download URL" >&2
	exit 1
fi

"${curl_executable}" -sS --fail -L "${url}" \
	-o "${work_dir}/usgs_cascadia_vs30.zip"
unzip -q "${work_dir}/usgs_cascadia_vs30.zip" -d "${work_dir}/extract"
source_tif="${work_dir}/extract/zipfolder/vs30_mosaic.tif"
if [[ ! -s "${source_tif}" ]]; then
	echo "USGS Vs30 archive did not contain vs30_mosaic.tif" >&2
	exit 1
fi

gmt grdmath "${source_tif}" 0 NAN = "${work_dir}/vs30_raw.nc"
gmt grdconvert "${work_dir}/vs30_raw.nc" "${work_dir}/vs30.nc?vs30"
gmt grdedit "${work_dir}/vs30.nc?vs30" \
	-D+x"degrees_east"+y"degrees_north"+d"m/s"+t"USGS Global Hybrid Vs30 Mosaic, Cascadia crop"+r"USGS server-side extraction for -130/-116/39/52"
mv "${work_dir}/vs30.nc" "${output}"
printf 'USGS Cascadia Vs30 cached in %s\n' "${output}"
