#!/bin/bash

set -e

# 0 : docker
# 1 : singularity
JOBTYPE="1"

# True : use global tag
# False : no global tag
GLOBALTAG="True"

# 7TeV
# 8TeV
# 13TeV
COM="7TeV"

# Production name
PRODNAME="7TeV_tnp"

CWD=${PWD}

# Define path for job directories
BASE_PATH="${PWD}/${PRODNAME}"
mkdir -p $BASE_PATH

#voms-proxy-init -voms cms -valid 172:00

if [ -e "${PWD}/AOD2NanoAOD" ];then
    cd AOD2NanoAOD
    git pull origin main
    cd ${CWD}
else
    git clone https://github.com/UKM-HEP/AOD2NanoAODOutreachTool.git AOD2NanoAOD
fi

#creating tarball
echo "Tarring up submit..."
tar -chzf AOD2NanoAOD.tgz AOD2NanoAOD

# Set processes
PROCESSES=( \
    JPsiToMuMu_2MuPEtaFilter \
    Run2011A_MuOnia \
    DYJetsToLL_M-10To50_TuneZ2 \
    DYJetsToLL_M-50 \
    Run2011A_SingleElectron \
    Run2011B_SingleElectron \
    Run2011A_SingleMu \
    Run2011B_SingleMu \
    Run2011A_DoubleElectron \
    Run2011B_DoubleElectron \
    Run2011A_DoubleMu \
    Run2011B_DoubleMu \
    )

# Create JDL files and job directories
for PROCESS in ${PROCESSES[@]}
do
    python create_job.py $PROCESS $BASE_PATH $JOBTYPE $GLOBALTAG $COM
    scp AOD2NanoAOD.tgz $BASE_PATH/$PROCESS
    scp /tmp/x509up_u$(id -u) $BASE_PATH/$PROCESS/x509up
done

# Submit jobs
#THIS_PWD=$PWD
#for PROCESS in ${PROCESSES[@]}
#do
#    cd $BASE_PATH/$PROCESS
#    condor_submit job.jdl
#    cd $THIS_PWD
#done

rm -rf AOD2NanoAOD  AOD2NanoAOD.tgz
