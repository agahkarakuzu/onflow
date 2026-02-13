// ========================================
// FSL ROI Extraction Process
// ========================================
// Extract a region of interest (ROI) from an image using specified coordinates

process FSL_ROI {
    tag "${grouping_key[0]}_${grouping_key[1]}_${grouping_key[2]}_${image_type}_ROI"

    container params.containers.fsl

    input:
    tuple val(grouping_key),
          path(input_image),
          val(x_start),
          val(y_start),
          val(z_start),
          val(x_size),
          val(y_size),
          val(z_size),
          val(image_type)

    output:
    tuple val(grouping_key),
          path(output_file),
          val(image_type),
          emit: roi_image

    script:
    def (subject, session, run) = grouping_key
    // Construct BIDS-compliant filename (omit run if it's "NA")
    def run_part = (run && run != "NA") ? "_${run}" : ""
    output_file = "${subject}_${session}${run_part}_${image_type}_roi.nii.gz"

    """
    fslroi ${input_image} ${output_file} \\
        ${x_start} ${x_size} \\
        ${y_start} ${y_size} \\
        ${z_start} ${z_size}
    """
}
