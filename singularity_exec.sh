#!/bin/bash

# /cvmfs/singularity.opensciencegrid.org/opensciencegrid/osgvo-el6:latest

singularity exec --contain --ipc --pid \
                --home $PWD:/srv \
                --bind /cvmfs \
                /cvmfs/singularity.opensciencegrid.org/cmssw/cms:rhel6 \
                ./XX_PROCESS_XX.sh $1 $2 $3
