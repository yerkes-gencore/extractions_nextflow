# extractions_nextflow

Create a separate config for your run. Execute using the example command:

`nextflow run main.nf -c nextflow.config`

To do a dryrun test and see how many samplesheets were found, you can add the flag `-stub` to the nextflow call to do a quick runthrough. 
Note that this will create some small text file outputs in your run directory as part of the test. These will be overwritten with actual files 
during the full run.

If nextflow is not added to your path, you can call the executable in the tools directory like this

`/yerkes-cifs/runs/tools/nextflow/nextflow_version_19.10.0_build_5170/nextflow run main.nf -c nextflow.config`

The outputs will be written to the folder specified in the config. 
