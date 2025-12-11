// ========================================
// ANTs Registration Process
// ========================================
// Wrapper for antsRegistrationSyN.sh with parameterized registration type
// Performs image registration between a fixed and moving image

process ANTS_REGISTRATION_SYN {
    tag "${grouping_key[0]}_${grouping_key[1]}_${grouping_key[2]}_${moving_type}_to_${fixed_type}"

    container params.containers.ants

    input:
    tuple val(grouping_key),
          path(fixed_image),
          path(moving_image),
          val(registration_type),
          val(fixed_type),
          val(moving_type)

    output:
    tuple val(grouping_key),
          path("${output_prefix}Warped.nii.gz"),
          path("${output_prefix}0GenericAffine.mat"),
          path("${output_prefix}InverseWarped.nii.gz"),
          val(fixed_type),
          val(moving_type),
          emit: registration_results

    script:
    def (subject, session, run) = grouping_key
    output_prefix = "${subject}_${session}_${run}_${moving_type}2${fixed_type}_"

    """
    antsRegistrationSyN.sh \\
        -d 3 \\
        -t ${registration_type} \\
        -f ${fixed_image} \\
        -m ${moving_image} \\
        -o ${output_prefix}
    """
}
