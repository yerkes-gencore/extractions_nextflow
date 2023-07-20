# extractions_nextflow

## Running 

This pipeline can be executed via the command resembling the following:

`nextflow run -latest yerkes-gencore/extractions_nextflow --run_dir <your_path>`

The `latest` argument tells nextflow to grab the most up-to-date version of the pipeline from this repo.
See the [Managing pipeline versions](#Managing-pipeline-versions) section for details.

The only 'required' parameter is `run_dir`: the location of the sequencing data.
See the next section for setting parameters.

If nextflow is not added to your path, you can call the executable in the tools directory like this

`/yerkes-cifs/runs/tools/nextflow/nextflow_version_19.10.0_build_5170/nextflow run ...`

The outputs will be written to the run_dir. 

## Parameters

Most pipeline parameters have reasonable defaults that you are unlikely to change between runs. 
If you do want to adjust params for a run, you can specify individual parameters 
directly on the command line. Single parameters can be set via the double-dash notation. E.g.

`nextflow run -latest yerkes-gencore/extractions_nextflow --run_dir <your_dir> --emails 'you@email.com'`

## Nextflow arguments

Nextflow arguments are specified using a single dash.

If you want to set many parameters without typing them all on the CLI,
you can pass a new config file to the pipeline via a `-c`. E.g.

`nextflow run -latest yerkes-gencore/extractions_nextflow -c <your_config_file>`

You can also run the pipeline with 'profiles' that will save a group of settings you 
can invoke with a single argument in the CLI. For example,

`nextflow run yerkes-gencore/extractions_nextflow --run_dir <your_path> -profile local_delayed`

Will execute the pipeline in the specified run directory after 24 hours. 
If you find yourself frequently declaring a set of parameters that differ from the default,
request a profile to be built for your needs. They are fast and easy. 

## Managing pipeline versions

The `-latest` argument can be provided to check the local copy of the pipeline against
the public repo. If the pipeline is out of date, this flag will ensure the latest
version is executed. You can remove this flag, which will cause the execution
to warn that you're running an out-of-date pipeline, but will still execute 
the version you have. This could be desirable if their are substantial changes
to the workflow that you aren't ready to adopt yet and want to keep your implementation
consistent. 

If you prefer to not default to using the newest version, you can install versions
of the pipeline manually using `nextflow pull yerkes-gencore/extractions_nextflow`.
You can also specify specific revisions of the pipeline if you want to revert to a
previous version. Use `-r` with a version tag such as a commit hash, branch name,
or release version. If we end up drastically changing the workflow, we may want to
use versioned releases to give easy handles for facilitating transition (or resistance
to it). 
