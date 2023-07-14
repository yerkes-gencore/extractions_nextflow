process runtime_snapshot {
    //publishDir "$pubDir", mode: 'move'
    input:
        path config
        val pubDir
    output:
        //path 'nextflow_extraction_run_details.txt'
        val 'ok'
    script:
    def summary = """\
    Pipeline execution summary
    ---------------------------
    Start   :   ${workflow.start}
    Command :   ${workflow.commandLine}
    runID   :   ${workflow.runName}
    workdir :   ${workflow.workDir}
    resumed?:   ${workflow.resume}

    Config snapshot
    ---------------------------
    """.stripIndent()
  
    """
    echo "$summary" >> ${pubDir}/nextflow_extraction_run_details.txt
    cat $config >> ${pubDir}/nextflow_extraction_run_details.txt
    """ 
    stub:
    """
    echo 'stubrun'# >> nextflow_extraction_run_details.txt
    """   
}

process check_params {
    output:
        stdout
    exec:
    println "\nRunning with parameters:"
    println "rundir: " + params.run_dir
    println "barcode_mismatches: " + params.barcode_mismatches
}

process mail_extraction_complete {
    input:
        val label
        val demuxfile
    exec:
    try {
        sendMail(
            to: "${params.emails}",
            subject: "Extraction $label Complete",
            attach: "${demuxfile}",
            body: "See the attachment for demultiplexing results"
        )
    } catch (e) {
        println 'Could not find extraction reports to mail'
    }
}
