#!/bin/bash

# Exit on error
set -e

export BASEDIR=`pwd`

echo "### Begin of job"

ID=$1
echo "ID:" $ID

PROCESS=$2
echo "Process:" $PROCESS

FILE=$3
echo "File:" $FILE

USER_=${USER}

EOS_HOME=/eos/${USER_:0:1}/${USER_}
echo "EOS home:" $EOS_HOME

# root://cmseos.fnal.gov//store/user/shoh/nanoaod/${PROCESS}/${outfilename}_nanoaod.root
#AAAX=root://cmseos.fnal.gov/
OUTPUT_DIR=${EOS_HOME}/opendata_files
echo "Output directory:" $OUTPUT_DIR

# inside docker
CMSSW_BASE=/home/cmsusr/CMSSW_5_3_32
echo "CMSSW base:" $CMSSW_BASE

echo "CMSSW config:" $CONFIG

echo "Hostname:" `hostname`

echo "How am I?" `id`

echo "Where am I?" `pwd`

echo "What is my system?" `uname -a`

echo "### Start working"

# Trigger auto mount of EOS
ls -la $EOS_HOME

# Make output directory
mkdir -p ${OUTPUT_DIR}/${PROCESS}

# Prepare EDMAnalyzer
THIS_DIR=$PWD
cd ${CMSSW_BASE}/src
scp ${BASEDIR}/AOD2NanoAOD.tgz $CMSSW_BASE/src
tar xvaf submit.tgz
eval `scramv1 runtime -sh`
cd $THIS_DIR

if [[ ${FILE} == *"Run2012"* ]]; then
    CONFIG=${CMSSW_BASE}/src/workspace/AOD2NanoAOD/configs/data_cfg.py
else
    CONFIG=${CMSSW_BASE}/src/workspace/AOD2NanoAOD/configs/simulation_cfg.py
fi

# Copy config file
mkdir -p configs/
CONFIG_COPY=configs/cfg_${ID}.py
cp $CONFIG $CONFIG_COPY

# Modify CMSSW config to run only a single file
sed -i -e "s,^files =,files = ['"${FILE}"'] #,g" $CONFIG_COPY
sed -i -e 's,^files.extend,#files.extend,g' $CONFIG_COPY

# Modify CMSSW config to read lumi mask from EOS
sed -i -e 's,data/Cert,'${CMSSW_BASE}'/src/workspace/AOD2NanoAOD/data/Cert,g' $CONFIG_COPY

# Modify config to write output directly to EOS
sed -i -e 's,output.root,'${PROCESS}_${ID}.root',g' $CONFIG_COPY

# Print config
cat $CONFIG_COPY

# Run CMSSW config
cmsRun $CONFIG_COPY

# Copy output file
xrdcp -f ${PROCESS}_${ID}.root root://eosuser.cern.ch/${OUTPUT_DIR}/${PROCESS}/${PROCESS}_${ID}.root
rm ${PROCESS}_${ID}.root

echo "### End of job"
