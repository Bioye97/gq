#!/usr/bin/env bash
# Shared staging and plotting helpers for the Cascadia Ely GTL examples.

# GMT scales colorbar text by sqrt(bar length / 15 cm). For a 2.3 inch bar,
# 16p produces an effective annotation and label size of approximately 10p.
elygtl_colorbar_font=16p

elygtl_surface_map() {
	local cube=$1 variable=$2 top=$3 output=$4 step=${5:-1}
	local level layer next
	layer="${work_dir}/surface_layer.nc"
	next="${work_dir}/surface_next.nc"
	# Keep the first finite value encountered from the shallowest layer downward.
	gmt grdconvert "${cube}?${variable}[0]" "${output}" -Vq
	for ((level = step; level <= top; level += step)); do
		gmt grdconvert "${cube}?${variable}[${level}]" "${layer}" -Vq
		gmt grdmath "${output}" "${layer}" DENAN = "${next}"
		mv "${next}" "${output}"
	done
}

elygtl_plot_vs() {
	local output=$1 map_region=$2 section_region=$3 map_projection=$4
	local section_projection=$5 map_x=$6 map_y=$7 section_x=$8
	local section_y=$9 coast=${10}
	local maps=(vs30 original ely)
	local map_titles=("USGS Vs30" "Original surface" "Ely GTL surface")
	local map_letters=(a b c)
	local sections=(original ely difference)
	local section_titles=("Original" "Ely GTL" "Difference")
	local section_letters=(d e f)
	local ps="${work_dir}/$(basename "${output}").ps"
	local index name title cpt y_axis

	for index in 0 1 2; do
		name=${maps[index]}
		title="(${map_letters[index]}) ${map_titles[index]}"
		cpt=${velocity_cpt}
		[[ ${name} == vs30 ]] && cpt=${vs30_cpt}
		y_axis=${map_y}
		if ((index == 0)); then
			gmt grdimage "${work_dir}/${name}_map.nc" -P -R${map_region} \
				-J${map_projection} -C"${cpt}" "${map_x}" "${map_y}" \
				"-BWSen+t${title}" -X0.65i -Y3.65i -K > "${ps}"
		else
			gmt grdimage "${work_dir}/${name}_map.nc" -R -J \
				-C"${cpt}" "${map_x}" "${y_axis}" "-BwSen+t${title}" \
				-X2.55i -O -K >> "${ps}"
		fi
		if [[ ${coast} == geographic ]]; then
			gmt pscoast -R -J -W0.7p,black -N1/0.5p,gray30 -O -K >> "${ps}"
		else
			gmt psxy "${coast}" -R -J -W0.7p,black -O -K >> "${ps}"
		fi
		gmt psxy "${work_dir}/profile_map.txt" -R -J -W1.5p,black,-- \
			-O -K >> "${ps}"
	done

	for index in 0 1 2; do
		name=${sections[index]}
		title="(${section_letters[index]}) ${section_titles[index]}"
		cpt=${velocity_cpt}
		[[ ${name} == difference ]] && cpt=${difference_cpt}
		y_axis=${section_y}
		if ((index == 0)); then
			gmt grdimage "${work_dir}/${name}_section.nc" \
				-R${section_region} -J${section_projection} -C"${cpt}" \
				"${section_x}" "${section_y}" "-BWSen+t${title}" -fc \
				-X-5.1i -Y-2.65i -O -K >> "${ps}"
		else
			gmt grdimage "${work_dir}/${name}_section.nc" -R -J \
				-C"${cpt}" "${section_x}" "${y_axis}" "-BwSen+t${title}" \
				-fc -X2.55i -O -K >> "${ps}"
		fi
	done

	gmt psscale -R -J -C"${vs30_cpt}" \
		-Dx-5.1i/-0.63i+w2.3i/0.11i+h -Bxa200f100+l"Vs30 (m/s)" \
		--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
		--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
	gmt psscale -R -J -C"${velocity_cpt}" \
		-Dx-2.55i/-0.63i+w2.3i/0.11i+h -Bxa1f0.5+l"Vs (km/s)" \
		--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
		--FONT_LABEL=${elygtl_colorbar_font} -O -K >> "${ps}"
	gmt psscale -R -J -C"${difference_cpt}" \
		-Dx0i/-0.63i+w2.3i/0.11i+h -Bxa1f0.5+l"Difference (km/s)" \
		--FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
		--FONT_LABEL=${elygtl_colorbar_font} -O >> "${ps}"

	gmt psconvert "${ps}" -A+m0.12i -Tf -F"${output}"
	gmt psconvert "${ps}" -A+m0.12i -Tg -E300 -F"${output}"
}

elygtl_plot_parameters() {
	local output=$1 section_region=$2 projection=$3 x_axis=$4 y_axis=$5
	shift 5
	local parameters=("$@")
	local ps="${work_dir}/$(basename "${output}").ps"
	local count=${#parameters[@]} index name label cpt scale y_frame finish
	local row_reset offset
	row_reset=$(awk -v count="${count}" 'BEGIN {printf "%.2fi", -2.55 * (count - 1)}')

	for index in "${!parameters[@]}"; do
		IFS=: read -r name label cpt scale <<< "${parameters[index]}"
		y_frame=${y_axis}
		if ((index == 0)); then
			gmt grdimage "${work_dir}/original_${name}_section.nc" -P \
				-R${section_region} -J${projection} -C"${cpt}" "${x_axis}" \
				"${y_axis}" "-BWSen+t($(printf '%b' "\\$(printf '%03o' $((97 + index)))")) Original ${label}" \
				-fc -X0.65i -Y4.0i -K > "${ps}"
		else
			gmt grdimage "${work_dir}/original_${name}_section.nc" -R -J \
				-C"${cpt}" "${x_axis}" "${y_frame}" \
				"-BwSen+t($(printf '%b' "\\$(printf '%03o' $((97 + index)))")) Original ${label}" \
				-fc -X2.55i -O -K >> "${ps}"
		fi
	done

	for index in "${!parameters[@]}"; do
		IFS=: read -r name label cpt scale <<< "${parameters[index]}"
		y_frame=${y_axis}
		if ((index == 0)); then
			gmt grdimage "${work_dir}/ely_${name}_section.nc" \
				-R${section_region} -J${projection} -C"${cpt}" "${x_axis}" \
				"${y_axis}" "-BWSen+t($(printf '%b' "\\$(printf '%03o' $((97 + count + index)))")) Ely GTL ${label}" \
				-fc -X${row_reset} -Y-2.55i -O -K >> "${ps}"
		else
			gmt grdimage "${work_dir}/ely_${name}_section.nc" -R -J \
				-C"${cpt}" "${x_axis}" "${y_frame}" \
				"-BwSen+t($(printf '%b' "\\$(printf '%03o' $((97 + count + index)))")) Ely GTL ${label}" \
				-fc -X2.55i -O -K >> "${ps}"
		fi
	done

	for index in "${!parameters[@]}"; do
		IFS=: read -r name label cpt scale <<< "${parameters[index]}"
		offset=$(awk -v idx="${index}" -v count="${count}" \
			'BEGIN {printf "%.2fi", 2.55 * (idx - count + 1)}')
		finish=-K
		((index == count - 1)) && finish=
		gmt psscale -R -J -C"${cpt}" \
			-Dx${offset}/-0.75i+w2.3i/0.11i+h \
			"${scale}" --FONT_ANNOT_PRIMARY=${elygtl_colorbar_font} \
			--FONT_LABEL=${elygtl_colorbar_font} \
			-O ${finish} >> "${ps}"
	done

	gmt psconvert "${ps}" -A+m0.12i -Tf -F"${output}"
	gmt psconvert "${ps}" -A+m0.12i -Tg -E300 -F"${output}"
}
