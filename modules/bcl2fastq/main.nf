process check_RTAComplete {
    input:
        val 'ok'
    output:
        val 'ok'
    exec:
    // def wait_time = params.max_wait * 60 * 60  // Maximum wait time in seconds 
    def sleep_interval = params.wait_interval * 60 * 1000 * 10 // 10 minutes
    def start_time = System.currentTimeMillis()
    def max_millis = params.max_wait * 60 * 60 * 1000 // params.max_wait * 1 hour
    //def input_file = "${params.run_dir}/RTAComplete.txt"
    def file_exists = file("${params.run_dir}/RTAComplete.txt").exists()
    if (!file_exists){
        println "Waiting up to ${params.max_wait} hours for sequencing run to complete."
        println "If RTAComplete file not found by then, workflow will close."
        println "This can be adjusted in the config."
    }
    while (!file_exists) {
        def elapsed = System.currentTimeMillis() - start_time
        if (elapsed > max_millis) {
            throw new RuntimeException("File RTAComplete.txt not found after ${params.max_wait} hours")
        }
        sleep(sleep_interval)
        file_exists = file("${params.run_dir}/RTAComplete.txt").exists()
    }
    // cd ${params.run_dir}
    
    // start_time=\$(date +%s)  # Get the start time in seconds since the epoch

    // while [ ! -f "RTAComplete.txt" ] && [ \$((\$(date +%s) - \$start_time)) -lt ${wait_time} ]; do
    //     sleep ${sleep_interval} # Wait for 20 minutes (1200 seconds) before checking again
    // done

    // if [ -f "RTAComplete.txt" ]; then
    //     echo "File found!"
    // else
    //     echo "Maximum wait time exceeded, file not found"
    // fi
    
    // Wait 1 minutes in case bcl files aren't finished writing 
    println 'RTA detected! Waiting a minute to ensure files are finished writing'
    sleep(60 * 1000) 
    // """
    // """
    // stub:
    // """
    // """
}

process bcl2fastq {
    errorStrategy  { task.attempt <= maxRetries  ? 'retry' : 'finish' }
    maxRetries 2
    maxForks params.maxForks
    publishDir "${run_dir}", mode: 'copy'
    input: 
        val seq_complete
        val run_dir
        val sheet    
        val mismatch_values                                  
    output:
        val output_label, emit: label
        val "${run_dir}/Unaligned_${output_label}", emit: output_dir
        // path "extract_*"
        // val "${params.run_dir}/Unaligned_${output_label}/Reports/html/*/all/all/all/laneBarcode.html", emit: laneBarcode
        // path "Unaligned_${output_label}/Stats/DemultiplexingStats.xml", emit: demux_stats
    script:
        // label outputs
        if (params.sample_sheets.isEmpty()){
            output_label = task.index
        } else if (params.sample_sheets.containsKey(sheet.toString())) {
            output_label = params.sample_sheets[sheet.toString()]
        } else {
            output_label = task.index
        }
        // allow quick devruns
        def tile_subset = (workflow.profile == 'dev_test') ? '--tiles [0-9][0-9][0-9]5' : ''
        // allow retries with looser settings
        def barcode_mismatches = (task.attempt == 1) ? mismatch_values : '0'
                // --ignore-missing-bcls \
                // --ignore-missing-filter \
                // --ignore-missing-positions \
        """
        bcl2fastq \
            --output-dir ${run_dir}/Unaligned_${output_label} \
            --sample-sheet ${sheet} \
            --runfolder-dir ${run_dir} \
            --barcode-mismatches ${barcode_mismatches} \
            --fastq-compression-level ${params.compression} \
            ${tile_subset} >> ${run_dir}/extract_${output_label}.stderr >> ${run_dir}/extract_${output_label}.stdout
        """
}

process xml_parse {
    publishDir "${params.run_dir}", mode: 'copy'
    stageOutMode 'copy'
    errorStrategy 'ignore'
    input:
        val output_label
        val output_dir
        //path statsfile
    output:
        // you would think this workflow would be better if you output the actual file as a path, not a val, but apparently not 
        val "${params.run_dir}/DemultiplexingStats_${output_label}.csv", emit: demuxstats
        // val "${params.run_dir}/Unaligned_${output_label}/DemultiplexingStats_${output_label}.csv", emit: demux_file_path
        val output_label, emit: label
    script:
    """
    python ${projectDir}/scripts/xmlParse.py ${output_dir}/Stats/DemultiplexingStats.xml DemultiplexingStats_${output_label}.csv
    """
}