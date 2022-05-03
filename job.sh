#!/bin/bash

#set -e

echo "### Begin of job"

# Setting
export SCRAM_ARCH=slc6_amd64_gcc472
export CMSSW_VERSION=CMSSW_5_3_32
export BASEDIR=${PWD}
export X509_USER_PROXY=${BASEDIR}/x509up

echo "BASEDIR          : " $BASEDIR
ID=$1
echo "ID               : " $ID
PROCESS=$2
echo "Process          : " $PROCESS
FILE=$3
echo "File             : " $FILE
EOS_HOME=/eos/user/XX_U_XX/XX_USER_XX
echo "EOS home         : " $EOS_HOME
OUTPUT_DIR=${EOS_HOME}/opendata_files
echo "Output directory : " $OUTPUT_DIR
echo "voms-proxy-info  : "
voms-proxy-info -all
voms-proxy-info -all -file x509up 

# setup CMSSW
echo "Setting up ${CMSSW_VERSION}"
source /cvmfs/cms.cern.ch/cmsset_default.sh
scramv1 project CMSSW ${CMSSW_VERSION}
cd ${CMSSW_VERSION}/src
eval `scramv1 runtime -sh`
echo "CMSSW should now be available."
#export LD_LIBRARY_PATH=${UPDATE_PATH}/lib:${UPDATE_PATH}/lib64:${LD_LIBRARY_PATH}
#export PATH=${UPDATE_PATH}/bin:${PATH}

# Prepare EDMAnalyzer
echo "Preparing EDMAnalyzer"
mkdir -p workspace
cd workspace
mv ${BASEDIR}/AOD2NanoAOD.tgz .
tar xvaf AOD2NanoAOD.tgz
rm AOD2NanoAOD.tgz
cd ${CMSSW_BASE}/src
scram b -j4
ls ${PWD}

if [[ ${FILE} == *"Run2012"* ]]; then
    CONFIG=${CMSSW_BASE}/src/workspace/AOD2NanoAOD/configs/data_cfg.py
else
    CONFIG=${CMSSW_BASE}/src/workspace/AOD2NanoAOD/configs/simulation_cfg.py
fi

# What is inside the container?
echo ""
echo "What is inside the container"
echo "CMSSW base    : " $CMSSW_BASE
echo "CMSSW config  : " $CONFIG
echo "Hostname      : " `hostname`
echo "How am I      : " `id`
echo "Who am I      : " $USER
echo "Where am I    : " `pwd`
echo "How many core : " `nproc`
echo "Memoery Avail : " `free -h`
echo "What is my system?" `uname -a`
echo ""

echo "### Start working"

# copy config file
cd $BASEDIR
mkdir -p configs/
CONFIG_COPY=configs/cfg_${ID}.py
cp $CONFIG $CONFIG_COPY

# Modify CMSSW config to run only a single file
sed -i -e "s,^files =,files = ['"${FILE}"'] #,g" $CONFIG_COPY
sed -i -e 's,^files.extend,#files.extend,g' $CONFIG_COPY

# Modify CMSSW config to read lumi mask from EOS
#sed -i -e 's,data/Cert,'${CMSSW_BASE}'/src/workspace/AOD2NanoAOD/data/Cert,g' $CONFIG_COPY

# Modify config to write output directly to EOS
sed -i -e 's,output.root,'${PROCESS}_${ID}.root',g' $CONFIG_COPY

# Print config
cat $CONFIG_COPY

# Run CMSSW config
cmsRun $CONFIG_COPY

# Copy output file
# root://eosuser.cern.ch//eos/user/s/shoh/opendata_files/README.md
# root://cmseos.fnal.gov//store/user/shoh/nanoaod/${PROCESS}/${outfilename}_nanoaod.root
ls -trlh .
pwd
xrdcp -f ${PROCESS}_${ID}.root root://eosuser.cern.ch/${OUTPUT_DIR}/${PROCESS}/${PROCESS}_${ID}.root
rm ${PROCESS}_${ID}.root

echo "### End of job"
