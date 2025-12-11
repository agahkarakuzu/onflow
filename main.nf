include { bids2nf } from './bids2nf/main.nf'
include { optic_nerve_registration } from './subworkflows/optic_nerve_registration.nf'

workflow {
    // Load BIDS data using bids2nf
    unified_results = bids2nf(params.bids_dir)

    unified_results.view()
    
    // Run optic nerve registration pipeline
    // optic_nerve_registration(unified_results)
}