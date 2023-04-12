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