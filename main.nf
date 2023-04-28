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

def validations() {
    try { 
        file(params.run_dir, checkIfExists: true)
    } catch (e) {
        println "\nRun directory not found. See reference in config.\n\nExiting\n"
        exit 1
    }
    if (!(params.sample_sheets.isEmpty() || (params.sample_sheets instanceof Map && params.sample_sheets.every { k, v -> v instanceof String } ))) {
        println "Parameter 'sample_sheets' is not a map of strings (or empty), please correct and rerun"
        exit 1
    }
}
validations()

// ////////////////////////////////////////////////////
// /* --              PROCESSES                   -- */
// ////////////////////////////////////////////////////

include { check_RTAComplete; bcl2fastq; xml_parse } from './modules/bcl2fastq/main.nf'
include { md5checksums } from './modules/md5sum/main.nf'
include { runtime_snapshot; mail_extraction_complete } from './modules/workflow_records/main.nf'

// ////////////////////////////////////////////////////
// /* --               WORKFLOW                   -- */
// ////////////////////////////////////////////////////


if (params.delay_start.toFloat() > 0) {
    println "Delaying worfklow by ${params.delay_start} hours"
    Thread.sleep((params.delay_start.toFloat()*1000*3600).intValue())
}

workflow extractions {
    main:
        runtime_snapshot(workflow.configFiles.toSet().last(), params.run_dir)
        if (params.sample_sheets.isEmpty()) {
            Channel.fromPath("${params.run_dir}/*[Dd][Ee][Mm][Uu][Xx]*.csv", type: 'file')
                .set{ sample_sheets }
        } else {
            Channel.fromList(params.sample_sheets.keySet())
                .set{ sample_sheets }
        }
        check_RTAComplete()
        bcl2fastq(check_RTAComplete.out, sample_sheets)
        xml_parse(bcl2fastq.out.label)
        if (params.emails?.trim()){
            mail_extraction_complete(xml_parse.out.label, xml_parse.out.demux_file_path)
        }
        if (params.compute_md5sums) {
            md5checksums(bcl2fastq.out.label.collect())
        }
    emit:
        bcl2fastq.out.output_dir
}

workflow {
    println "Workflow start: $workflow.start"
    extractions()
}

// workflow.onComplete {
//     if (workflow.profile != 'dryrun') {
//         if (params.emails?.trim()){
//             def msg = """\
//             Pipeline execution summary
//             ---------------------------
//             Completed at    : ${workflow.complete}
//             Duration        : ${workflow.duration}
//             Success         : ${workflow.success}
//             workDir         : ${workflow.workDir}
//             exit status     : ${workflow.exitStatus}
//             runDir          : ${params.run_dir}
//             NF runName      : ${workflow.runName}
//             """
//             .stripIndent()
//             sendMail(to: "${params.emails}", subject: 'Extraction Complete', body: msg)
//         } 
//     }
// }


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

// have to pass in a file in the output folder, the completed file would be a good indicator
// when a file is passed, the parent directory is mounted with the docker container
    //seq_complete_ch = Channel.watchPath("${params.run_dir}/RTAComplete.txt", 'create,modify')
    //    .take(1)// .until { file -> file.name != 'asd' }
        //.flatMap { file -> Channel.value(file) }
        // .until { file -> file.name != 'asd' }
        // .set{ seq_complete }
    //seq_complete_ch.view()