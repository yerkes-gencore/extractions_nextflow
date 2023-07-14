process check_RTAComplete {
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
    sleep(60 * 1000) 
    // """
    // """
    // stub:
    // """
    // """
}

process bcl2fastq {
    //errorStrategy 'finish'
    maxForks params.maxForks
    publishDir "${params.run_dir}/Unaligned_${output_label}", mode: 'copy'
    input: 
        val seq_complete
        val sheet                                      
    output:
        //path "Unaligned*", type: 'dir'
        val output_label, emit: label
        path "Unaligned_${output_label}/*", emit: output_dir
        //val "${params.run_dir}/Unaligned_${output_label}/Reports/html/*/all/all/all/laneBarcode.html", emit: laneBarcode
        //path "Unaligned_${output_label}/Stats/DemultiplexingStats.xml"
    script:
    if (params.sample_sheets.isEmpty()){
        output_label = task.index
    } else if (params.sample_sheets.containsKey(sheet.toString())) {
        output_label = params.sample_sheets[sheet.toString()]
    } else {
        output_label = task.index
    }
        //     #--loading-threads 10 \
        // #--processing-threads 10 \
        // #--writing-threads 10 \
    """
    #cd ${params.run_dir}
    bcl2fastq \
        --output-dir Unaligned_${output_label} \
        --sample-sheet ${sheet} \
        --runfolder-dir ${params.run_dir} \
        --barcode-mismatches ${params.barcode_mismatches} \
        --fastq-compression-level ${params.compression} > extract_${output_label}.stderr > extract_${output_label}.stdout
    mv extract_${output_label}.std* Unaligned_${output_label}/
    #cp ${sheet} Unaligned_${output_label}/
    """
    stub:
    if (params.sample_sheets.isEmpty()){
        output_label = task.index
    } else if (params.sample_sheets.containsKey(sheet.toString())) {
        output_label = params.sample_sheets[sheet.toString()]
    } else {
        output_label = task.index
    }
    """
    """
}

process xml_parse {
    publishDir "${params.run_dir}/Unaligned_${output_label}/", mode: 'copy'
    input:
        val output_label
        //path statsfile
    output:
        path "DemultiplexingStats.csv", emit: demuxstats
        val "${params.run_dir}/Unaligned_${output_label}/DemultiplexingStats.csv", emit: demux_file_path
        val output_label, emit: label
    script:
    """
    python ${projectDir}/scripts/xmlParse.py ${params.run_dir}/Unaligned_${output_label}/Stats/DemultiplexingStats.xml DemultiplexingStats.csv
    """
}