#!/usr/bin/env nextflow
nextflow.enable.dsl=2

def helpMessage() {
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    ./nextflow run extractions.nf -c nextflow.config

    Edit the nextflow.config file to add run parameters
    """.stripIndent()
}

// Show help message
params.help = ""
if (params.help) {
    helpMessage()
    exit 0
}

// ////////////////////////////////////////////////////
// /* --          VALIDATE INPUTS                 -- */
// ////////////////////////////////////////////////////


// ////////////////////////////////////////////////////
// /* --              PROCESSES                   -- */
// ////////////////////////////////////////////////////


process bcl2fastq {
    maxForks params.maxForks
    //publishDir "${params.run_dir}", mode: 'move'
    input: 
        val seq_complete
        val sheet                                      
    output:
        //path "Unaligned*", type: 'dir'
        val output_label//, emit: output_label
        //path "Unaligned_${output_label}/Stats/DemultiplexingStats.xml"
    script:
    if (params.sample_sheets.isEmpty()){
        output_label = task.index
    } else if (params.sample_sheets.containsKey(sheet.toString())) {
        output_label = params.sample_sheets[sheet.toString()]
    } else {
        output_label = task.index
    }
    """
    cd ${params.run_dir}
    bcl2fastq \
        --output-dir Unaligned_${output_label} \
        --sample-sheet ${sheet} \
        --runfolder-dir ${params.run_dir} \
        --fastq-compression-level ${params.compression} \
        #--loading-threads 10 \
        #--processing-threads 10 \
        #--writing-threads 10 \
        > extract_${output_label}.stderr > extract_${output_label}.stdout
    #mv extract_${output_label}.stderr Unaligned_${output_label}/
    #mv extract_${output_label}.stdout Unaligned_${output_label}/
    cp ${sheet} Unaligned_${output_label}/
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
    publishDir "${params.run_dir}/Unaligned_${output_label}/"
    input:
        val output_label
        //path statsfile
    output:
        path 'DemultiplexingStats.csv'
    script:
    """
    python ${projectDir}/scripts/xmlParse.py ${params.run_dir}/Unaligned_${output_label}/Stats/DemultiplexingStats.xml DemultiplexingStats.csv
    """
    stub:
    """
    touch DemultiplexingStats.csv
    """
}

process delay_start {
    input:
        val time
    // output:
    //     stdout
    """
    #echo "delaying extraction by ${params.delay_start} hours"
    sleep ${time}h
    """

    stub:
    """
    """
}

process check_RTAComplete {
    output:
        val 'ok'
    script:
    // def wait_time = params.max_wait * 60 * 60  // Maximum wait time in seconds 
    def sleep_interval = params.wait_interval * 60 * 1000
    def start_time = System.currentTimeMillis()
    def max_millis = params.max_wait * 60 * 60 * 1000
    //def input_file = "${params.run_dir}/RTAComplete.txt"
    def file_exists = file("${params.run_dir}/RTAComplete.txt").exists()
    println "Waiting up to ${params.max_wait} hours for sequencing run to complete."
    println "If RTAComplete file not found by then, workflow will close."
    println "This can be adjusted in the config."
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
    """
    """
    stub:
    """
    """
}

process md5checksums {
    input:
        val(trigger)
    shell:
    """
    cd ${params.run_dir}
    for fastqdir in \$(find ~+ -iname '*.fastq.gz' -exec dirname '{}' \\; | sort -u); do date; echo \${fastqdir}; cd \${fastqdir}; md5sum *.fastq.gz > \$(basename \${fastqdir})-md5checklist.txt; date; done
    """
    stub:
    """
    """
}

process runtime_snapshot {
    publishDir "${params.run_dir}", mode: 'move'
    input:
        path config
    output:
        path 'nextflow_extraction_run_details.txt'
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
    echo "$summary" >> nextflow_extraction_run_details.txt
    cat $config >> nextflow_extraction_run_details.txt
    """ 
    stub:
    """
    echo 'stubrun' >> nextflow_extraction_run_details.txt
    """   
}

workflow {
    println "Workflow start: $workflow.start"
    runtime_snapshot(workflow.configFiles.toSet())
    if (params.delay_start.toFloat() > 0) {
        println "Delaying extraction by ${params.delay_start} hours"
        delay_start(params.delay_start.toFloat())
    }
    // have to pass in a file in the output folder, the completed file would be a good indicator
    // when a file is passed, the parent directory is mounted with the docker container
        //seq_complete_ch = Channel.watchPath("${params.run_dir}/RTAComplete.txt", 'create,modify')
        //    .take(1)// .until { file -> file.name != 'asd' }
            //.flatMap { file -> Channel.value(file) }
            // .until { file -> file.name != 'asd' }
            // .set{ seq_complete }
        //seq_complete_ch.view()
        if (params.sample_sheets.isEmpty()) {
            Channel.fromPath("${params.run_dir}/*[Dd][Ee][Mm][Uu][Xx]*.csv", type: 'file')
                .set{ sample_sheets }
        } else {
            Channel.fromList(params.sample_sheets.keySet())
                .set{ sample_sheets }
        }
        bcl2fastq(check_RTAComplete, sample_sheets)
        xml_parse(bcl2fastq.out)
        if (params.compute_md5sums) {
            md5checksums(bcl2fastq.out.collect())
        }
}

workflow.onComplete {
    if (workflow.profile != 'dryrun') {
        if (params.emails?.trim()){
            def msg = """\
            Pipeline execution summary
            ---------------------------
            Completed at    : ${workflow.complete}
            Duration        : ${workflow.duration}
            Success         : ${workflow.success}
            workDir         : ${workflow.workDir}
            exit status     : ${workflow.exitStatus}
            runDir          : ${params.run_dir}
            NF runName      : ${workflow.runName}
            """
            .stripIndent()
            sendMail(to: "${params.emails}", subject: 'Extraction Complete', body: msg)
        } 
    }
}


// ////////////////////////////////////////////////////
// /* --          IN DEVELOPMENT                  -- */
// ////////////////////////////////////////////////////

// process sync_bcl {
//     //container = "amazon/aws-cli"
//     //containerOptions = "-v $HOME/.aws/credentials"
//     input:
//         path run_dir
//     output:
//         stdout
//     """
//     aws --profile "tki-aws-account-65-rhedcloud/RHEDcloudAdministratorRole" \\
//         s3 sync ${params.run_dir} s3://yerkes-gencore-archive/2022_runs/${params.run_name}/ \\
//         --exclude "*.fastq.gz" --exclude "localcheck*.txt" --exclude "remotecheck*.txt" --exclude "md5-*-Data.txt" --exclude "md5-*-Fastq.txt" \\
//         --no-follow-symlinks --only-show-errors --dryrun 
//     #aws --profile "tki-aws-account-65-rhedcloud/RHEDcloudAdministratorRole" \\
//     #    s3 ls --recursive s3://yerkes-gencore-fastq-archive/2022_runs/${params.run_name}/ | \\
//     #    gawk '{print \$3,\$4}' | sort | sed 's/2022_runs\///1' > remotecheckfastq-${params.run_name}-Fastq.txt
//     """
// }

// process alignment {
//     publishDir "${params.align_outdir}/${project}", mode: 'move'
//     input:
//         tuple val(sample), path('reads?.fastq.gz')
//         //path working_files
//     output:
//         path "**ReadsPerGene.out.tab"
//         //stdout
//     script:
//     project = (sample =~ '.+/fastqs/([^/]+)/.+').findAll()[0][1]
//     file_prefix = (sample =~ '.+/(.+)').findAll()[0][1]
//     """  
//     ${params.alignment_star_versions[project]} \\
//         --genomeDir ${params.alignment_references[project]} \\
//         --genomeLoad NoSharedMemory \\
//         --readFilesIn reads* \\
//         --readFilesCommand zcat \\
//         --runThreadN ${params.alignment_cores} \\
//         --outStd Log \\
//         --outSAMattributes None \\
//         --outSAMmode None \\
//         --outSAMunmapped None \\
//         --outFilterMultimapNmax 999 \\
//         --outSAMprimaryFlag AllBestScore \\
//         --quantMode ${params.quantMode} 
//     """
//     /*
//     """
//     ${params.alignment_star_versions[project]} \\
//         --genomeDir ${params.alignment_references[project]} \\
//         --genomeLoad NoSharedMemory \\
//         --readFilesIn ${file_prefix}* \\
//         --readFilesCommand zcat \\
//         --runThreadN ${params.alignment_cores} \\
//         --outStd Log \\
//         --outSAMattributes None \\
//         --outSAMmode None \\
//         --outSAMunmapped None \\
//         --outFilterMultimapNmax 999 \\
//         --outSAMprimaryFlag AllBestScore \\
//         --quantMode ${params.quantMode} 
//     """
//     /* | sed -E 's/.+\/test\/([^\/]+)\/.+/\1/')
//     a='/yerkes-cifs/runs/tools/automation/extractions/test/bcl2fastq_out/p22207_Nils/p22207-s002_VTF-75-P1-TMPSS-LC0702876_S2_L001_R1_001.fastq.gz'
//     pat='.+\/bcl2fastq_out\/([^\/]+)\/.+'
//     [[ $a =~ $pat ]]
//     echo \${BASH_REMATCH[1]}

//     --outFileNamePrefix ${params.alignment_prefix[project]} \\
//     #pattern='.+/test/([^/]+)/.+'
//     #[[ "${files[1][0]}" =~ \$pattern ]]
//     #project=\${BASH_REMATCH[1]}
//     #echo \$project
//     #echo ${params.alignment_references['p22207_Nils']}
//     */
    
//     // """
// }

// process sync_fastq {
//     input:
//         path x
//         val y
//     output:
//         stdout
//     """
//     aws --profile "tki-aws-account-65-rhedcloud/RHEDcloudAdministratorRole" \\
//         s3 sync ${x} s3://yerkes-gencore-fastq-archive/2022_runs/${params.run_name}/ \\
//         --exclude "*" --include "*.fastq.gz" \\
//         --no-follow-symlinks --only-show-errors --dryrun 
//     """
// }

// process init_repo {
//     conda 'conda-forge::gh'
//     output:
//         stdout
//     """
//     gh repo create yerkes-gencore/${params.project_name} --template yerkes-gencore/bulk_template --private
//     """
// }