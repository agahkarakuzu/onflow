// ========================================
// Initial Registration Subworkflow
// ========================================
// Performs the initial multi-stage registration pipeline:
// 1. Extract b0 from DWI
// 2. Register DWI b0 → T1w (rigid)
// 3. Register T1w → MNI (rigid)
// 4. Apply combined transforms to DWI → MNI
// 5. Apply transforms to all derivatives (segmentations, FA, T1map)

include { ANTS_REGISTRATION_SYN as DWI_TO_T1W_REG } from '../modules/registration/ants_registration_syn.nf'
include { ANTS_REGISTRATION_SYN as T1W_TO_MNI_REG } from '../modules/registration/ants_registration_syn.nf'
include { ANTS_APPLY_TRANSFORMS as APPLY_DWI_TO_MNI } from '../modules/registration/ants_apply_transforms.nf'
include { ANTS_APPLY_TRANSFORMS as APPLY_DERIVATIVES_TO_MNI } from '../modules/registration/ants_apply_transforms.nf'
include { DWI_B0_EXTRACTION } from '../modules/preprocessing/dwi_b0_extraction.nf'

workflow initial_registration {
    take:
    bids_data       // Channel: tuple(groupingKey, enrichedData) from bids2nf
    mni_template    // Path to MNI template

    main:

    // ========================================
    // Extract relevant images from bids2nf output
    // ========================================
    subject_data = bids_data.map { groupingKey, enrichedData ->
        def data = enrichedData.data

        tuple(
            groupingKey,
            file(data.UNIT1.nii),                                          // UNIT1 (defaced T1w)
            file(data.dwi.nii),                                            // DWI
            file(data.dwi.bval),                                           // bvals
            data.containsKey('FA') ? file(data.FA.nii) : null,            // FA map (optional)
            data.containsKey('T1map') ? file(data.T1map.nii) : null,      // T1 map (optional)
            data.containsKey('mask') && data.mask.nii.containsKey('anat') ?
                file(data.mask.nii.anat) : null,                          // mask anatomical (optional)
            data.containsKey('mask') && data.mask.nii.containsKey('dwi') ?
                file(data.mask.nii.dwi) : null                            // mask dwi (optional)
        )
    }

    // ========================================
    // Step 1: Extract b0 from DWI
    // ========================================
    b0_extraction_input = subject_data.map { groupingKey, t1w, dwi, bval, fa, t1map, t1seg, dwiseg ->
        tuple(groupingKey, dwi, bval)
    }

    DWI_B0_EXTRACTION(b0_extraction_input)

    // ========================================
    // Step 2: Register DWI b0 to T1w (rigid)
    // ========================================
    dwi2t1w_input = subject_data
        .join(DWI_B0_EXTRACTION.out.b0_image, by: 0)
        .map { groupingKey, t1w, dwi, bval, fa, t1map, t1seg, dwiseg, b0 ->
            tuple(
                groupingKey,
                t1w,                                           // fixed
                b0,                                            // moving
                params.registration.dwi_to_t1w_type,          // registration type
                'T1w',                                         // fixed type
                'b0'                                           // moving type
            )
        }

    DWI_TO_T1W_REG(dwi2t1w_input)
    dwi2t1w_results = DWI_TO_T1W_REG.out.registration_results

    // ========================================
    // Step 3: Register T1w to MNI (rigid)
    // ========================================
    t1w2mni_input = subject_data.map { groupingKey, t1w, dwi, bval, fa, t1map, t1seg, dwiseg ->
        tuple(
            groupingKey,
            mni_template,                                  // fixed
            t1w,                                           // moving
            params.registration.t1w_to_mni_type,          // registration type
            'MNI',                                         // fixed type
            'T1w'                                          // moving type
        )
    }

    T1W_TO_MNI_REG(t1w2mni_input)
    t1w2mni_results = T1W_TO_MNI_REG.out.registration_results

    // ========================================
    // Step 4: Apply combined transforms to b0 → MNI
    // ========================================
    // Need to chain two transforms: b0→T1w, then T1w→MNI
    // Note: We transform the b0 (not full DWI) to match the notebook approach
    dwi_to_mni_input = subject_data
        .join(DWI_B0_EXTRACTION.out.b0_image, by: 0)  // Get the b0 volume
        .join(dwi2t1w_results, by: 0)
        .join(t1w2mni_results, by: 0)
        .map { groupingKey, t1w, dwi, bval, fa, t1map, t1seg, dwiseg, b0,
               dwi2t1w_warped, dwi2t1w_mat, dwi2t1w_inv, dwi2t1w_fixed, dwi2t1w_moving,
               t1w2mni_warped, t1w2mni_mat, t1w2mni_inv, t1w2mni_fixed, t1w2mni_moving ->
            tuple(
                groupingKey,
                b0,                                        // input: b0 instead of full DWI
                mni_template,                              // reference
                [t1w2mni_mat, dwi2t1w_mat],               // transforms (ANTs applies in REVERSE: dwi2t1w first, then t1w2mni)
                params.registration.interpolation.dwi,    // interpolation
                'b0',                                      // image type
                'MNI'                                      // reference type
            )
        }

    APPLY_DWI_TO_MNI(dwi_to_mni_input)
    dwi_in_mni = APPLY_DWI_TO_MNI.out.transformed_image

    // ========================================
    // Step 5: Apply transforms to derivatives
    // ========================================
    // Create channels for each derivative type with appropriate transforms
    derivative_channels = subject_data
        .join(dwi2t1w_results, by: 0)
        .join(t1w2mni_results, by: 0)
        .flatMap { groupingKey, t1w, dwi, bval, fa, t1map, t1seg, dwiseg,
                   dwi2t1w_warped, dwi2t1w_mat, dwi2t1w_inv, dwi2t1w_fixed, dwi2t1w_moving,
                   t1w2mni_warped, t1w2mni_mat, t1w2mni_inv, t1w2mni_fixed, t1w2mni_moving ->

            def results = []

            // Anatomical mask to MNI (only needs T1w→MNI transform)
            if (t1seg) {
                results << tuple(
                    groupingKey,
                    t1seg,
                    mni_template,
                    [t1w2mni_mat],
                    params.registration.interpolation.segmentation,
                    'mask_anat',
                    'MNI'
                )
            }

            // DWI mask to MNI (needs both transforms: DWI→T1w, T1w→MNI)
            if (dwiseg) {
                results << tuple(
                    groupingKey,
                    dwiseg,
                    mni_template,
                    [t1w2mni_mat, dwi2t1w_mat],  // ANTs applies in REVERSE
                    params.registration.interpolation.segmentation,
                    'mask_dwi',
                    'MNI'
                )
            }

            // FA map to MNI (needs both transforms: DWI→T1w, T1w→MNI)
            if (fa) {
                results << tuple(
                    groupingKey,
                    fa,
                    mni_template,
                    [t1w2mni_mat, dwi2t1w_mat],  // ANTs applies in REVERSE
                    params.registration.interpolation.fa_map,
                    'FA',
                    'MNI'
                )
            }

            // T1 map to MNI (only needs T1w→MNI transform)
            if (t1map) {
                results << tuple(
                    groupingKey,
                    t1map,
                    mni_template,
                    [t1w2mni_mat],
                    params.registration.interpolation.t1map,
                    'T1map',
                    'MNI'
                )
            }

            return results
        }

    APPLY_DERIVATIVES_TO_MNI(derivative_channels)
    derivatives_in_mni = APPLY_DERIVATIVES_TO_MNI.out.transformed_image

    // ========================================
    // Emit outputs for downstream workflows
    // ========================================
    emit:
    t1w_in_mni = t1w2mni_results              // T1w registered to MNI (with transforms)
    dwi_in_mni = dwi_in_mni                   // DWI in MNI space (initial)
    derivatives_in_mni = derivatives_in_mni   // All derivatives in MNI (initial)
    dwi_to_t1w_transform = dwi2t1w_results    // For reference
    t1w_to_mni_transform = t1w2mni_results    // For reference
}
