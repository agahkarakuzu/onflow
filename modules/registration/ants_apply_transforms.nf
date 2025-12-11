    // ========================================
    // ANTs Apply Transforms Process
    // ========================================
    // Apply transformations to images with flexible transform lists
    // Handles single transform or multiple chained transforms

    process ANTS_APPLY_TRANSFORMS {
        tag "${grouping_key[0]}_${grouping_key[1]}_${grouping_key[2]}_${image_type}_to_${reference_type}"

        container params.containers.ants

        input:
        tuple val(grouping_key),
            path(input_image),
            path(reference_image),
            path(transform),      // Can be single file or list of files
            val(interpolation),
            val(image_type),
            val(reference_type)

        output:
        tuple val(grouping_key),
            path(output_file),
            val(image_type),
            val(reference_type),
            emit: transformed_image

        script:
        def (subject, session, run) = grouping_key
        output_file = "${subject}_${session}_${run}_${image_type}_in_${reference_type}.nii.gz"

        // Handle multiple transforms (they should be applied in order)
        // If transform is a list, create multiple -t arguments
        // ANTs applies transforms in the order they are specified
        def transform_args = transform instanceof List ?
            transform.collect { "-t ${it}" }.join(' ') :
            "-t ${transform}"

        """
        antsApplyTransforms \\
            -d 3 \\
            -i ${input_image} \\
            -r ${reference_image} \\
            -o ${output_file} \\
            -n ${interpolation} \\
            ${transform_args}
        """
    }
