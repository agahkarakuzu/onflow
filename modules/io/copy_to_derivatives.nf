process COPY_TO_DERIVATIVES {

    tag "${grouping_key[0]}_${grouping_key[1]}_${grouping_key[2]}_${datatype}_${suffix}"

    publishDir {
        def subject = grouping_key[0]
        def session = grouping_key[1]
        def base = "${params.bids_dir}/derivatives/onflow"

        def subject_clean = (subject && subject != "NA") ? subject.replaceAll(/^(sub|ses|run)-/, '') : 'NA'
        def session_clean = (session && session != "NA") ? session.replaceAll(/^(sub|ses|run)-/, '') : null

        session_clean ?
            "${base}/sub-${subject_clean}/ses-${session_clean}/${datatype}" :
            "${base}/sub-${subject_clean}/${datatype}"
    },
    mode: params.output.publish_mode

    input:
    tuple val(grouping_key),
          path(input_file),
          val(datatype),
          val(suffix),
          val(desc)

    output:
    path output_file, emit: derivative_file

    script:
    def (subject, session, run) = grouping_key

    def subject_clean = (subject && subject != "NA") ? subject.replaceAll(/^(sub|ses|run)-/, '') : 'NA'
    def session_clean = (session && session != "NA") ? session.replaceAll(/^(sub|ses|run)-/, '') : ''
    def run_clean     = (run && run != "NA") ? run.replaceAll(/^(sub|ses|run)-/, '') : ''
    def run_part      = run_clean ? "_run-${run_clean}" : ""
    def desc_part     = desc ? "_desc-${desc}" : ""
    def session_part  = session_clean ? "_ses-${session_clean}" : ""
    def subject_part  = "sub-${subject_clean}"

    output_file = "${subject_part}${session_part}${run_part}${desc_part}_${suffix}.nii.gz"

    """
    cp ${input_file} ${output_file}
    """
}