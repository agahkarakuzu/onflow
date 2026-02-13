// ========================================
// Optic Nerve Registration - Main Orchestrator Subworkflow
// ========================================
// Combines all registration stages and prepares BIDS derivatives outputs
//
// Pipeline stages:
// 1. Initial registration (DWI→T1w→MNI)
// 2. ROI-based refinement
// 3. Prepare outputs with proper BIDS naming
// 4. Copy to derivatives directory

include { initial_registration } from './initial_registration.nf'
include { roi_refinement } from './roi_refinement.nf'
include { COPY_TO_DERIVATIVES } from '../modules/io/copy_to_derivatives.nf'

workflow optic_nerve_registration {
    take:
    bids_data  // Channel from bids2nf workflow: tuple(groupingKey, enrichedData)

    main:

    // Load MNI template
    mni_template = file(params.mni152_template)

    // ========================================
    // Stage 1: Initial Registration
    // ========================================
    initial_registration(bids_data, mni_template)

    // ========================================
    // Stage 2: ROI-based Refinement
    // ========================================
    roi_refinement(
        initial_registration.out.t1w_in_mni,
        initial_registration.out.dwi_in_mni,
        initial_registration.out.derivatives_in_mni
    )

    // ========================================
    // Stage 3: Prepare outputs for BIDS derivatives
    // ========================================
    // Combine initial T1w-derived results (not refined) with
    // refined DWI-derived results

    // T1w in MNI (not refined)
    t1w_output = initial_registration.out.t1w_in_mni
        .map { groupingKey, warped, mat, inv, fixed, moving ->
            tuple(
                groupingKey,
                warped,
                'anat',      // datatype
                'T1w',       // suffix
                'MNI'        // description
            )
        }

    // T1map in MNI (not refined) - from derivatives
    t1map_output = initial_registration.out.derivatives_in_mni
        .filter { groupingKey, img, imgType, refType ->
            imgType == 'T1map'
        }
        .map { groupingKey, img, imgType, refType ->
            tuple(
                groupingKey,
                img,
                'anat',      // datatype
                'T1map',     // suffix
                'MNI'        // description
            )
        }

    // Anatomical mask in MNI (not refined)
    t1wseg_output = initial_registration.out.derivatives_in_mni
        .filter { groupingKey, img, imgType, refType ->
            imgType == 'mask_anat'
        }
        .map { groupingKey, img, imgType, refType ->
            tuple(
                groupingKey,
                img,
                'anat',      // datatype
                'dseg',      // suffix (standard BIDS)
                'MNI'        // description
            )
        }

    // Refined DWI-derived images
    refined_output = roi_refinement.out.refined_images
        .map { groupingKey, img, imgType, refType ->
            def datatype = 'dwi'  // All refined outputs are DWI-related

            // Map image type to proper BIDS suffix
            def suffix = imgType
            def desc = 'MNIcorrected'

            if (imgType == 'mask_dwi_corrected') {
                suffix = 'dseg'
            } else if (imgType == 'dwi_corrected') {
                suffix = 'dwi'
            } else if (imgType == 'FA_corrected') {
                suffix = 'FA'
            }

            tuple(
                groupingKey,
                img,
                datatype,
                suffix,
                desc
            )
        }

    // ========================================
    // Stage 4: Combine all outputs and copy to derivatives
    // ========================================
    all_outputs = t1w_output
        .mix(t1map_output)
        .mix(t1wseg_output)
        .mix(refined_output)

    COPY_TO_DERIVATIVES(all_outputs)

    // ========================================
    // Emit final derivatives
    // ========================================
    emit:
    derivatives = COPY_TO_DERIVATIVES.out.derivative_file
}
