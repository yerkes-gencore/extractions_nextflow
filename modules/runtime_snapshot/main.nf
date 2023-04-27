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
