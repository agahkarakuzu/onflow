// ========================================
// DWI b0 Extraction Process
// ========================================
// Extract the first b0 volume from a DWI dataset
//
// ENHANCEMENT OPPORTUNITY:
// This is a simplified version that extracts the first volume.
// Future enhancement could parse the bval file to:
//   1. Find all volumes with b=0
//   2. Average multiple b0 volumes if available
//   3. Select the optimal b0 volume

process DWI_B0_EXTRACTION {
    tag "${grouping_key[0]}_${grouping_key[1]}_${grouping_key[2]}"

    container params.containers.fsl

    input:
    tuple val(grouping_key),
          path(dwi_nii),
          path(bval)

    output:
    tuple val(grouping_key),
          path(output_file),
          emit: b0_image

    script:
    def (subject, session, run) = grouping_key
    output_file = "${subject}_${session}_${run}_b0.nii.gz"

    """
    # Extract first volume (assumed to be b0)
    # This uses fslroi to extract volume 0 (one volume starting at index 0)
    fslroi ${dwi_nii} ${output_file} 0 1
    """
}
