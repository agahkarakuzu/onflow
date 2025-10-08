include { bids2nf } from './bids2nf/main.nf'
include { unified_process_template } from './bids2nf/modules/templates/unified_process_template.nf'

include { 
    getLoopOverEntities
} from './bids2nf/modules/utils/config_analyzer.nf'

workflow {
  
  unified_results = bids2nf(params.bids_dir)
  

  def bids_basename = new File(params.bids_dir).getName()
  
  // Add basename to each result for template use
  unified_results_with_basename = unified_results.map { groupingKey, enrichedData ->
    def updatedData = enrichedData + [bidsBasename: bids_basename]
    tuple(groupingKey, updatedData)
  }
  
  unified_results_with_basename.view()
  
  // unified_process_template(unified_results_with_basename, params.includeBidsParentDir)
}