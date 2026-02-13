// ========================================
// ROI-based Refinement Subworkflow
// ========================================
// Performs ROI-based registration refinement for improved alignment:
// 1. Create ROI from T1w in MNI space using optic nerve coordinates
// 2. Create ROI from DWI in MNI space using same coordinates
// 3. Register DWI_ROI → T1w_ROI (rigid refinement)
// 4. Apply refinement transform to DWI-derived images only
//
// Note: Only DWI-derived images (dwi, mask_dwi, FA) are refined.
// T1w-derived images (T1w, mask_anat, T1map) use initial registration.

include { FSL_ROI as T1W_ROI_EXTRACT } from '../modules/roi/fsl_roi.nf'
include { FSL_ROI as DWI_ROI_EXTRACT } from '../modules/roi/fsl_roi.nf'
include { ANTS_REGISTRATION_SYN as ROI_REFINEMENT_REG } from '../modules/registration/ants_registration_syn.nf'
include { ANTS_APPLY_TRANSFORMS as APPLY_ROI_REFINEMENT } from '../modules/registration/ants_apply_transforms.nf'

workflow roi_refinement {
    take:
    t1w_in_mni           // T1w registered to MNI (from initial_registration)
    dwi_in_mni           // DWI registered to MNI (initial, from initial_registration)
    derivatives_in_mni   // All derivatives in MNI (initial, from initial_registration)

    main:

    // ========================================
    // Step 1: Create T1w ROI in MNI space
    // ========================================
    t1w_roi_input = t1w_in_mni.map { groupingKey, warped, mat, inv, fixed, moving ->
        tuple(
            groupingKey,
            warped,
            params.registration.roi_coordinates.x_start,
            params.registration.roi_coordinates.y_start,
            params.registration.roi_coordinates.z_start,
            params.registration.roi_coordinates.x_size,
            params.registration.roi_coordinates.y_size,
            params.registration.roi_coordinates.z_size,
            'T1w'
        )
    }

    T1W_ROI_EXTRACT(t1w_roi_input)
    t1w_roi = T1W_ROI_EXTRACT.out.roi_image

    // ========================================
    // Step 2: Create DWI ROI in MNI space
    // ========================================
    dwi_roi_input = dwi_in_mni.map { groupingKey, image, imageType, refType ->
        tuple(
            groupingKey,
            image,
            params.registration.roi_coordinates.x_start,
            params.registration.roi_coordinates.y_start,
            params.registration.roi_coordinates.z_start,
            params.registration.roi_coordinates.x_size,
            params.registration.roi_coordinates.y_size,
            params.registration.roi_coordinates.z_size,
            'dwi'
        )
    }

    DWI_ROI_EXTRACT(dwi_roi_input)
    dwi_roi = DWI_ROI_EXTRACT.out.roi_image

    // ========================================
    // Step 3: Register DWI ROI to T1w ROI (rigid refinement)
    // ========================================
    roi_registration_input = t1w_roi
        .join(dwi_roi, by: 0)
        .map { groupingKey, t1w_roi_img, t1w_type, dwi_roi_img, dwi_type ->
            tuple(
                groupingKey,
                t1w_roi_img,                              // fixed
                dwi_roi_img,                              // moving
                params.registration.roi_refinement_type,  // registration type
                'T1w_ROI',                                // fixed type
                'dwi_ROI'                                 // moving type
            )
        }

    ROI_REFINEMENT_REG(roi_registration_input)
    roi_refinement_results = ROI_REFINEMENT_REG.out.registration_results

    // ========================================
    // Step 4: Apply refinement transform to DWI-derived images
    // ========================================
    // Only refine DWI-derived images (mask_dwi, FA)
    // T1w-derived images are not refined as they don't need the DWI→T1w correction
    derivative_refinement_input = derivatives_in_mni
        .join(roi_refinement_results, by: 0)
        .join(t1w_in_mni, by: 0)
        .map { groupingKey,
               deriv_img, deriv_type, deriv_ref,
               roi_warped, roi_mat, roi_inv, roi_fixed, roi_moving,
               t1w_warped, t1w_mat, t1w_inv, t1w_fixed, t1w_moving ->

            // Only refine DWI-derived images (mask_dwi, FA)
            if (deriv_type == 'mask_dwi' || deriv_type == 'FA') {
                tuple(
                    groupingKey,
                    deriv_img,
                    t1w_warped,                           // reference is T1w in MNI
                    [roi_mat],                            // refinement transform
                    deriv_type.contains('seg') ?
                        params.registration.interpolation.segmentation :
                        params.registration.interpolation.fa_map,
                    "${deriv_type}_corrected",            // mark as corrected
                    'MNI'
                )
            } else {
                // Don't refine T1w-derived images
                null
            }
        }
        .filter { it != null }

    // ========================================
    // Also refine the DWI itself
    // ========================================
    dwi_refinement_input = dwi_in_mni
        .join(roi_refinement_results, by: 0)
        .join(t1w_in_mni, by: 0)
        .map { groupingKey,
               dwi_img, dwi_type, dwi_ref,
               roi_warped, roi_mat, roi_inv, roi_fixed, roi_moving,
               t1w_warped, t1w_mat, t1w_inv, t1w_fixed, t1w_moving ->
            tuple(
                groupingKey,
                dwi_img,
                t1w_warped,                               // reference is T1w in MNI
                [roi_mat],                                // refinement transform
                params.registration.interpolation.dwi,
                'dwi_corrected',
                'MNI'
            )
        }

    // Combine all refinement inputs
    all_refinement_inputs = derivative_refinement_input.mix(dwi_refinement_input)

    APPLY_ROI_REFINEMENT(all_refinement_inputs)
    refined_images = APPLY_ROI_REFINEMENT.out.transformed_image

    // ========================================
    // Emit outputs
    // ========================================
    emit:
    refined_images = refined_images         // Refined DWI-derived images
    roi_transform = roi_refinement_results  // ROI refinement transform (for reference)
}
