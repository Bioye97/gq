#!/usr/bin/env bash
#
# Demonstrate missing-value handling in text and NetCDF inputs.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
ncgen_executable=${NCGEN:-$(command -v ncgen || true)}
if [[ -z "${ncgen_executable}" ]]; then
	echo "ncgen was not found; set NCGEN=/path/to/ncgen" >&2
	exit 1
fi
gmt() {
	command "${gmt_executable}" "$@"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-ex06-missing.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_PEN thin,black MAP_GRID_PEN_PRIMARY default, \
	MAP_LABEL_OFFSET 0.1c MAP_TITLE_OFFSET 14p

primary_text="${script_dir}/primary.txt"
secondary_text="${script_dir}/secondary.txt"
primary_nc="${work_dir}/primary.nc"
secondary_nc="${work_dir}/secondary.nc"
text_mergefile="${work_dir}/text.merge"
netcdf_mergefile="${work_dir}/netcdf.merge"
text_result="${work_dir}/text_result.txt"
netcdf_result="${work_dir}/netcdf_result.txt"
text_interpolated="${work_dir}/text_interpolated.txt"
netcdf_interpolated="${work_dir}/netcdf_interpolated.txt"
netcdf_output="${work_dir}/netcdf_result.nc"
range=0/10/0.05
profile_region=0/10/1.5/9.5
weight_region=0/10/-0.05/1.05
availability_region=0/10/0/1
projection=X3.15i/2.25i
ps_file="${work_dir}/ex06_missing_values.ps"

# Text input uses NaN directly and declares -99999 through GMT's -di option.
cat > "${text_mergefile}" <<- EOF
	${primary_text} ${secondary_text} 0/10 cosine 0.2
	EOF
gmt merge1d "${text_mergefile}" -T${range} -Fvalue -W -di-99999 \
	-G"${text_result}"

# NetCDF input uses a declared _FillValue and an undeclared selector sentinel.
"${ncgen_executable}" -o "${primary_nc}" "${script_dir}/primary.cdl"
"${ncgen_executable}" -o "${secondary_nc}" "${script_dir}/secondary.cdl"
cat > "${netcdf_mergefile}" <<- EOF
	${primary_nc}?vp ${secondary_nc}?p+n-99999 0/10 cosine 0.2
	EOF
gmt merge1d "${netcdf_mergefile}" -T${range} -Fvalue -W \
	-G"${netcdf_result}"
gmt merge1d "${netcdf_mergefile}" -T${range} -Fvalue -W \
	-G"${netcdf_output}"
gmt merge1d "${text_mergefile}" -T${range} -Fvalue -W -di-99999 \
	-Sl+g -G"${text_interpolated}"
gmt merge1d "${netcdf_mergefile}" -T${range} -Fvalue -W \
	-Sl+g -G"${netcdf_interpolated}"
paste "${text_result}" "${netcdf_result}" | \
	awk '{
		for (i = 1; i <= 3; i++) {
			a = tolower($i)
			b = tolower($(i + 3))
			if (a == "nan" || b == "nan") {
				if (a != b) exit 1
			}
			else if (($i - $(i + 3))^2 > 1e-12) exit 1
		}
	}'
paste "${text_interpolated}" "${netcdf_interpolated}" | \
	awk '{
		for (i = 1; i <= 3; i++) {
			a = tolower($i)
			b = tolower($(i + 3))
			if (a == "nan" || b == "nan") {
				if (a != b) exit 1
			}
			else if (($i - $(i + 3))^2 > 1e-12) exit 1
		}
	}'

# Sample each source separately to expose the intervals interpolation retains.
gmt merge1d "${primary_text}" -T${range} -G"${work_dir}/primary_sampled.txt"
gmt merge1d "${secondary_text}" -T${range} -di-99999 \
	-G"${work_dir}/secondary_sampled.txt"
gmt merge1d "${primary_text}" -T${range} -Sl+g \
	-G"${work_dir}/primary_interpolated.txt"
gmt merge1d "${secondary_text}" -T${range} -di-99999 -Sl+g \
	-G"${work_dir}/secondary_interpolated.txt"
awk '{$2 = ($2 == -99999) ? "NaN" : $2; print}' \
	"${secondary_text}" > "${work_dir}/secondary_plot.txt"
awk '{print $1, (tolower($2) == "nan") ? "NaN" : 0.8}' \
	"${work_dir}/primary_sampled.txt" > "${work_dir}/primary_mask.txt"
awk '{print $1, (tolower($2) == "nan") ? "NaN" : 0.5}' \
	"${work_dir}/secondary_sampled.txt" > "${work_dir}/secondary_mask.txt"
awk '{print $1, (tolower($2) == "nan") ? "NaN" : 0.2}' \
	"${text_result}" > "${work_dir}/output_mask.txt"

# Validate finite-member fallback and the interval where both sources are missing.
awk '$1 == 4 {if (($2 - 2.8)^2 > 1e-18) exit 1; found = 1}
	 END {if (!found) exit 1}' "${text_result}"
awk '$1 == 5 {if (tolower($2) != "nan") exit 1; found = 1}
	 END {if (!found) exit 1}' "${text_result}"
awk '$1 == 7 {if (($2 - 7.5)^2 > 1e-18) exit 1; found = 1}
	 END {if (!found) exit 1}' "${text_result}"
awk '$1 == 5 {if (($2 - 7.5)^2 > 1e-18) exit 1; found = 1}
	 END {if (!found) exit 1}' "${text_interpolated}"
awk 'tolower($2) == "nan" {exit 1}' "${text_interpolated}"

cat > "${work_dir}/legend_inputs.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Primary
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Secondary
	EOF
cat > "${work_dir}/legend_weight.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,deepskyblue 0.28i Merging weight
	EOF
cat > "${work_dir}/legend_merged.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue,- 0.28i Primary
	S 0.08i - 0.22i - 1.5p,orangered,- 0.28i Secondary
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i Merged
	EOF
cat > "${work_dir}/legend_availability.txt" <<- EOF
	S 0.08i - 0.22i - 1.5p,royalblue 0.28i Primary
	S 0.08i - 0.22i - 1.5p,orangered 0.28i Secondary
	S 0.08i - 0.22i - 1.5p,seagreen 0.28i Output
	EOF

# Panel (a): gaps split each source into independent interpolation runs.
gmt psbasemap -P -R${profile_region} -J${projection} -Bxa2f1 \
	-Bya2f1+l"Value" -BWSen+t"(a) Input series" \
	-X0.8i -Y8.2i -K > "${ps_file}"
gmt psxy "${primary_text}" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${primary_text}" -R -J -Sc0.07i -Groyalblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_plot.txt" -R -J -W1.5p,orangered \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_plot.txt" -R -J -Sc0.07i -Gorangered \
	-O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_inputs.txt" -R -J -DjMC \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (b): the merging weight is independent of data availability.
gmt psbasemap -R${weight_region} -J${projection} -Bxa2f1 \
	-Bya0.2f0.1+l"Weight" -BWSen+t"(b) Merging weight" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${text_result}" -i0,2 -R -J -W1.5p,deepskyblue -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_weight.txt" -R -J -DjMC \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (c): one available member is retained; two missing members produce NaN.
gmt psbasemap -R${profile_region} -J${projection} -Bxa2f1 \
	-Bya2f1+l"Value" -BWSen+t"(c) Merged without interpolation" \
	-X-3.75i -Y-3.0i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary_sampled.txt" -R -J -W1.5p,royalblue,- \
	-O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_sampled.txt" -R -J -W1.5p,orangered,- \
	-O -K >> "${ps_file}"
gmt psxy "${text_result}" -i0,1 -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_merged.txt" -R -J -DjMC \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (d): output is unavailable only where neither input can contribute.
gmt psbasemap -R${availability_region} -J${projection} \
	-Bxa2f1 -Bya0.2f0.1+l"Availability" \
	-BWSen+t"(d) Available intervals" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary_mask.txt" -R -J -W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary_mask.txt" -R -J -Sc0.035i -Groyalblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_mask.txt" -R -J -W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_mask.txt" -R -J -Sc0.035i -Gorangered -O -K >> "${ps_file}"
gmt psxy "${work_dir}/output_mask.txt" -R -J -W1.5p,seagreen -O -K >> "${ps_file}"
gmt psxy "${work_dir}/output_mask.txt" -R -J -Sc0.035i -Gseagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_availability.txt" -R -J -DjMC+o0/0.33i \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (e): +g bridges every internal missing interval in each source.
gmt psbasemap -R${profile_region} -J${projection} -Bxa2f1+l"Coordinate" \
	-Bya2f1+l"Value" -BWSen+t"(e) Interpolated inputs" \
	-X-3.75i -Y-3.0i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary_interpolated.txt" -R -J \
	-W1.5p,royalblue -O -K >> "${ps_file}"
gmt psxy "${primary_text}" -R -J -Sc0.07i -Groyalblue -O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_interpolated.txt" -R -J \
	-W1.5p,orangered -O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_plot.txt" -R -J \
	-Sc0.07i -Gorangered -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_inputs.txt" -R -J -DjMC \
	-F+p0.4p -O -K >> "${ps_file}"

# Panel (f): the merge uses the interpolated members produced by -Sl+g.
gmt psbasemap -R${profile_region} -J${projection} -Bxa2f1+l"Coordinate" \
	-Bya2f1+l"Value" -BWSen+t"(f) Merged after interpolation" \
	-X3.75i -O -K >> "${ps_file}"
gmt psxy "${work_dir}/primary_interpolated.txt" -R -J \
	-W1.5p,royalblue,- -O -K >> "${ps_file}"
gmt psxy "${work_dir}/secondary_interpolated.txt" -R -J \
	-W1.5p,orangered,- -O -K >> "${ps_file}"
gmt psxy "${text_interpolated}" -i0,1 -R -J \
	-W1.5p,seagreen -O -K >> "${ps_file}"
gmt pslegend "${work_dir}/legend_merged.txt" -R -J -DjMC \
	-F+p0.4p -O >> "${ps_file}"

gmt psconvert "${ps_file}" -A -Tf \
	-F"${script_dir}/ex06_missing_values"
gmt psconvert "${ps_file}" -A -Tg -E300 \
	-F"${script_dir}/ex06_missing_values"
