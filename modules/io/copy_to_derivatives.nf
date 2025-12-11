// ========================================
// Copy to BIDS Derivatives Process
// ========================================
// Handle BIDS derivatives output naming and directory structure
// Automatically builds paths based on grouping_key hierarchy

process COPY_TO_DERIVATIVES {
    tag "${grouping_key[0]}_${grouping_key[1]}_${grouping_key[2]}_${datatype}_${suffix}"

    publishDir "${params.output.base_dir}/${publish_dir}",
               mode: params.output.publish_mode,
               pattern: "*.nii.gz"

    input:
    tuple val(grouping_key),
          path(input_file),
          val(datatype),      // 'anat' or 'dwi'
          val(suffix),        // 'T1w', 'dwi', 'dseg', 'FA', 'T1map'
          val(desc)           // description label (e.g., 'MNI', 'MNIcorrected')

    output:
    path(output_file), emit: derivative_file

    script:
    def (subject, session, run) = grouping_key

    // Build BIDS derivatives path components
    // Handle NA values - only include in path if not NA
    def session_part = (session != "NA" && session != null && session != "") ? "ses-${session}" : ""
    def run_part = (run != "NA" && run != null && run != "") ? "_run-${run}" : ""
    def desc_part = (desc != null && desc != "") ? "_desc-${desc}" : ""

    // Determine publish directory based on BIDS structure
    // If session exists: sub-{subject}/ses-{session}/{datatype}
    // If no session: sub-{subject}/{datatype}
    publish_dir = session_part ?
        "sub-${subject}/${session_part}/${datatype}" :
        "sub-${subject}/${datatype}"

    // Build BIDS-compliant filename
    // Format: sub-{subject}[_ses-{session}][_run-{run}][_desc-{desc}]_{suffix}.nii.gz
    def subject_part = "sub-${subject}"
    def session_filename = session_part ? "_${session_part}" : ""

    output_file = "${subject_part}${session_filename}${run_part}${desc_part}_${suffix}.nii.gz"

    """
    cp ${input_file} ${output_file}
    """
}
