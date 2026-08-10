#!/usr/bin/env bash
#
# Apply topography to the multiparameter SVI EQTOMO model.

set -euo pipefail

gmt_executable=${GMT:-$(command -v gmt || true)}
if [[ -z "${gmt_executable}" ]]; then
	echo "GMT was not found; set GMT=/path/to/gmt" >&2
	exit 1
fi
gmt() {
	if [[ $1 == topobath && -n "${GQ_TOPOBATH_RUNNER:-}" ]]; then
		shift
		if [[ -z "${GQ_PLUGIN:-}" ]]; then
			echo "GQ_PLUGIN is required with GQ_TOPOBATH_RUNNER" >&2
			exit 1
		fi
		GQ_PLUGIN="${GQ_PLUGIN}" command "${GQ_TOPOBATH_RUNNER}" "$@"
	else
		command "${gmt_executable}" "$@"
	fi
}
plot_depth_label() {
	gmt pstext -R -J -F+cBR+f10p,Helvetica,black+jBR+t"0 km" \
		-D-0.08i/0.08i -Gwhite -C0.08c -N -O -K
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
data_dir="${script_dir}/../../data/cascadia"
prepare_script="${data_dir}/prepare_vs_slices.sh"
model_file="${data_dir}/SVI_EQTOMO_Savard2018.r0.1.nc"
relief_file="${data_dir}/cascadia_earth_relief_01m_g.nc"

if [[ ! -s "${model_file}" ]]; then
	GMT="${gmt_executable}" "${prepare_script}"
fi
if [[ ! -s "${relief_file}" ]]; then
	gmt grdcut @earth_relief_01m_g -R-130/-116/39/52 \
		-G"${relief_file}"
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gq-topobath-ex03-svi.XXXXXX")
trap 'rm -rf "${work_dir}"' EXIT
cd "${work_dir}"

gmt set FONT_ANNOT_PRIMARY 10p FONT_LABEL 10p FONT_TITLE 11p \
	MAP_FRAME_TYPE plain MAP_FRAME_PEN thin,black \
	MAP_GRID_PEN_PRIMARY default, MAP_LABEL_OFFSET 0.1c \
	MAP_TITLE_OFFSET 14p COLOR_NAN white

region=-126/-121.1/47/50.9
increment=0.1
section_latitude=49
model="${model_file}?Vp,Vs,Density+Zkm"
relief="${relief_file}?z+z-0.001+Zkm"
original="${work_dir}/original.nc"
pull="${work_dir}/pull.nc"
extend="${work_dir}/extend.nc"
linear="${work_dir}/linear.nc"
old_surface="${work_dir}/old_surface.nc"
classification="${work_dir}/classification.nc"
water=(-WVp/1.5+t0.01 -WVs/0+t0.01 -WDensity/1.03+t0.01)

# Resample the flat baseline and process all three parameters together.
gmt topobath "${model}" -Or -R${region} -I${increment} -T0/2/0.1 \
	"${water[@]}" -Dh -A0/0/1 \
	-Q"${old_surface}"+c"${classification}" -G"${original}"
gmt topobath "${model}" "${relief}" -Oa -Mp -R${region} -I${increment} \
	-T-5/2/0.1 -E"${old_surface}" "${water[@]}" \
	-Dh -A0/0/1 -G"${pull}"
gmt topobath "${model}" "${relief}" -Oa -Me -R${region} -I${increment} \
	-T-5/2/0.1 -E"${old_surface}" "${water[@]}" \
	-Dh -A0/0/1 -G"${extend}"
gmt topobath "${model}" "${relief}" -Oa -Ml -R${region} -I${increment} \
	-T-5/2/0.1 -E"${old_surface}" "${water[@]}" \
	-LVp/1.5 -LVs/0.5 -LDensity/2.3 \
	-Dh -A0/0/1 -G"${linear}"

fields=(Vp Vs Density)
keys=(vp vs density)
for index in 0 1 2; do
	field=${fields[index]}
	key=${keys[index]}
	gmt grdconvert "${original}?${field}[0]" \
		"${work_dir}/original_${key}_map.nc" -Vq
	for name in pull extend linear; do
		gmt grdconvert "${work_dir}/${name}.nc?${field}[50]" \
			"${work_dir}/${name}_${key}_map.nc" -Vq
	done

	gmt grdcut "${original}?${field}" -Ey${section_latitude} \
		-G"${work_dir}/original_${key}_section_native.nc" -Vq
	gmt grdcut "${work_dir}/original_${key}_section_native.nc" \
		-R-126/-121.1/-5/2 -NNaN \
		-G"${work_dir}/original_${key}_section.nc" -Vq
	for name in pull extend linear; do
		gmt grdcut "${work_dir}/${name}.nc?${field}" \
			-Ey${section_latitude} \
			-G"${work_dir}/${name}_${key}_section.nc" -Vq
	done
done

awk -v latitude="${section_latitude}" 'BEGIN {
	for (i = 0; i <= 49; i++) print -126 + 0.1 * i, latitude
}' > "${work_dir}/profile_points.txt"
gmt grdtrack "${work_dir}/profile_points.txt" -G"${relief_file}" | \
	awk '{print $1, -0.001 * $3}' > "${work_dir}/new_surface_profile.txt"
printf '%s 0\n%s 0\n' -126 -121.1 > "${work_dir}/flat_surface_profile.txt"

gmt grdmath "${work_dir}/extend_vs_section.nc" \
	"${work_dir}/linear_vs_section.nc" SUB = \
	"${work_dir}/method_difference.nc"
gmt grdinfo "${work_dir}/method_difference.nc" -C | \
	awk '$6 >= -1e-6 && $7 <= 1e-6 {exit 1}'

vp_cpt="${work_dir}/vp.cpt"
vs_cpt="${work_dir}/vs.cpt"
density_cpt="${work_dir}/density.cpt"
gmt makecpt -Cturbo -T1.5/9/0.25 -Z > "${vp_cpt}"
gmt makecpt -Cturbo -T0/5/0.1 -Z > "${vs_cpt}"
gmt makecpt -Cturbo -T1/3.5/0.05 -Z > "${density_cpt}"

section_region=-126/-121.1/-5/2

# Figure 1: all construction methods for Vs.
methods_ps="${work_dir}/ex03_svi_eqtomo_methods.ps"
names=(original pull extend linear)
titles=("Original" "Pull-up/push-down" "Constant extension" "Linear extension")
letters=(a b c d)
for index in 0 1 2 3; do
	name=${names[index]}
	title="(${letters[index]}) ${titles[index]}"
	y_axis=-Bya1f0.5
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Latitude"
		gmt grdimage "${work_dir}/${name}_vs_map.nc" -P -R${region} \
			-JM1.65i -C"${vs_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BWSen+t${title}" -X0.4i -Y3.4i \
			-K > "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_vs_map.nc" -R -J \
			-C"${vs_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -X2i \
			-O -K >> "${methods_ps}"
	fi
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 \
		-O -K >> "${methods_ps}"
	printf '%s %s\n%s %s\n' -126 "${section_latitude}" -121.1 \
		"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${methods_ps}"
	plot_depth_label >> "${methods_ps}"
done

section_letters=(e f g h)
for index in 0 1 2 3; do
	name=${names[index]}
	title="(${section_letters[index]}) ${titles[index]}"
	y_axis=-Bya1f0.5
	profile="${work_dir}/new_surface_profile.txt"
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Depth (km)"
		profile="${work_dir}/flat_surface_profile.txt"
		gmt grdimage "${work_dir}/${name}_vs_section.nc" \
			-R${section_region} -JX1.65i/-1.55i -C"${vs_cpt}" \
			-Bxa2f0.2+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
			-fc -X-6i -Y-2.25i -O -K >> "${methods_ps}"
	else
		gmt grdimage "${work_dir}/${name}_vs_section.nc" -R -J \
			-C"${vs_cpt}" -Bxa2f0.2+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -fc -X2i \
			-O -K >> "${methods_ps}"
	fi
	gmt psxy "${profile}" -R -J -W1.5p,black -fc \
		-O -K >> "${methods_ps}"
done

gmt psscale -R -J -C"${vs_cpt}" \
	-Dx-6i/-0.78i+w7.65i/0.12i+h -Bxa1f0.5+l"Vs (km/s)" \
	--FONT_ANNOT_PRIMARY=10p --FONT_LABEL=10p -O >> "${methods_ps}"
gmt psconvert "${methods_ps}" -A+m0.1i -Tf \
	-F"${script_dir}/ex03_svi_eqtomo_methods"
gmt psconvert "${methods_ps}" -A+m0.1i -Tg -E300 \
	-F"${script_dir}/ex03_svi_eqtomo_methods"

# Figure 2: all parameters from the linear construction.
parameters_ps="${work_dir}/ex03_svi_eqtomo_parameters.ps"
cpts=("${vp_cpt}" "${vs_cpt}" "${density_cpt}")
labels=("Vp" "Vs" "Density")
scales=('-Bxa2f1+lVp (km/s)' '-Bxa1f0.5+lVs (km/s)' \
	'-Bxa0.5f0.25+lDensity (g/cm@+3@+)')
# GMT 6.5 scales 1.8i colorbar fonts by bar length; 18.1p renders as 10p.
parameter_colorbar_font=18.1p

for index in 0 1 2; do
	key=${keys[index]}
	title="($(printf '%b' "\\$(printf '%03o' $((97 + index)))")) ${labels[index]} at sea level"
	y_axis=-Bya1f0.5
	if ((index == 0)); then
		y_axis=-Bya1f0.5+l"Latitude"
		gmt grdimage "${work_dir}/linear_${key}_map.nc" -P -R${region} \
			-JM2.1i -C"${cpts[index]}" -Bxa1f0.2+l"Longitude" \
			"${y_axis}" "-BWSen+t${title}" -X0.5i -Y5.6i \
			-K > "${parameters_ps}"
	else
		gmt grdimage "${work_dir}/linear_${key}_map.nc" -R -J \
			-C"${cpts[index]}" -Bxa1f0.2+l"Longitude" \
			"${y_axis}" "-BwSen+t${title}" -X2.55i \
			-O -K >> "${parameters_ps}"
	fi
	gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 \
		-O -K >> "${parameters_ps}"
	printf '%s %s\n%s %s\n' -126 "${section_latitude}" -121.1 \
		"${section_latitude}" | gmt psxy -R -J -W1.5p,black,-- \
		-O -K >> "${parameters_ps}"
	plot_depth_label >> "${parameters_ps}"
	gmt psscale -R -J -C"${cpts[index]}" \
		-DjBC+w1.8i/0.1i+h+o0/-0.78i \
		"${scales[index]}" \
		--FONT_ANNOT_PRIMARY=${parameter_colorbar_font} \
		--FONT_LABEL=${parameter_colorbar_font} -O -K \
		>> "${parameters_ps}"
done

for row in original linear; do
	if [[ ${row} == original ]]; then
		row_title=Original
		row_letters=(d e f)
		profile="${work_dir}/flat_surface_profile.txt"
		y_shift=-2.8i
	else
		row_title=Linear
		row_letters=(g h i)
		profile="${work_dir}/new_surface_profile.txt"
		y_shift=-2.15i
	fi
	for index in 0 1 2; do
		key=${keys[index]}
		title="(${row_letters[index]}) ${row_title} ${labels[index]}"
		y_axis=-Bya1f0.5
		if ((index == 0)); then
			y_axis=-Bya1f0.5+l"Depth (km)"
			gmt grdimage "${work_dir}/${row}_${key}_section.nc" \
				-R${section_region} -JX2.1i/-1.35i -C"${cpts[index]}" \
				-Bxa1f0.2+l"Longitude" "${y_axis}" "-BWSen+t${title}" \
				-fc -X-5.1i -Y${y_shift} -O -K >> "${parameters_ps}"
		else
			gmt grdimage "${work_dir}/${row}_${key}_section.nc" -R -J \
				-C"${cpts[index]}" -Bxa1f0.2+l"Longitude" \
				"${y_axis}" "-BwSen+t${title}" -fc -X2.55i \
				-O -K >> "${parameters_ps}"
		fi
		finish=-K
		if [[ ${row} == linear && ${index} -eq 2 ]]; then finish=; fi
		gmt psxy "${profile}" -R -J -W1.5p,black -fc \
			-O ${finish} >> "${parameters_ps}"
	done
done

gmt psconvert "${parameters_ps}" -A+m0.15i -Tf \
	-F"${script_dir}/ex03_svi_eqtomo_parameters"
gmt psconvert "${parameters_ps}" -A+m0.15i -Tg -E300 \
	-F"${script_dir}/ex03_svi_eqtomo_parameters"
