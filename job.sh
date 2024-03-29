#!/bin/bash

set -e

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
echo "Production Name  : XX_PRODNAME_XX" 
GT="None"
echo "Global Tag       : " $GT
echo "Era              : XX_ERA_XX"
echo "COM              : XX_COM_XX" 
EOS_HOME=/eos/user/XX_U_XX/XX_USER_XX
echo "EOS home         : " $EOS_HOME
OUTPUT_DIR=${EOS_HOME}/cmsopendata/XX_PRODNAME_XX/XX_ERA_XX/XX_COM_XX
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

if [[ ${FILE} == *"Run"* ]]; then
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

# Modify globaltag for realistic analysis application
if [[ ${GT} != "None" ]]; then
    
    echo "Using Global Tag: XX_GLOBALTAG_XX"

    # enable globaltag
    sed -i -e 's,#process.load(,process.load(,g' $CONFIG_COPY
    sed -i -e 's,#process.GlobalTag.connect,process.GlobalTag.connect,g' $CONFIG_COPY
    sed -i -e 's,#process.GlobalTag.globaltag,process.GlobalTag.globaltag,g' $CONFIG_COPY
    sed -i -e 's,USEGLOBALTAG,XX_GLOBALTAG_XX,g' $CONFIG_COPY

    # symbolic link to cond-db
    # http://opendata.cern.ch/docs/cms-guide-for-condition-database
    # ONLY for 8TeV DATA
    if [[ ${FILE} == *"Run2012"* ]]; then

	GT_XFULL=$(basename XX_GLOBALTAG_XX _FULL )
	sed -i -e 's,XX_GLOBALTAG_XX::All,'${GT_XFULL}'::All,g' $CONFIG_COPY
	
	ln -sf /cvmfs/cms-opendata-conddb.cern.ch/FT53_V21A_AN6_FULL FT53_V21A_AN6
	ln -sf /cvmfs/cms-opendata-conddb.cern.ch/FT53_V21A_AN6_FULL.db FT53_V21A_AN6_FULL.db
	ln -sf /cvmfs/cms-opendata-conddb.cern.ch/FT53_V21A_AN6_FULL FT53_V21A_AN6_FULL
    else
        ln -sf /cvmfs/cms-opendata-conddb.cern.ch/XX_GLOBALTAG_XX XX_GLOBALTAG_XX
        ln -sf /cvmfs/cms-opendata-conddb.cern.ch/XX_GLOBALTAG_XX.db XX_GLOBALTAG_XX.db
    fi
fi

# Modify CMSSW config to read lumi mask from EOS
if [[ ${FILE} == *"Run"* ]]; then

    if [[ ${FILE} == *"Run2012"* ]]; then
	# 8TeV
	sed -i -e 's,USECERTIFICATEHERE,'${CMSSW_BASE}'/src/workspace/AOD2NanoAOD/data/Cert_190456-208686_8TeV_22Jan2013ReReco_Collisions12_JSON.txt,g' $CONFIG_COPY
    else
	# 7TeV
	sed -i -e 's,USECERTIFICATEHERE,'${CMSSW_BASE}'/src/workspace/AOD2NanoAOD/data/Cert_160404-180252_7TeV_ReRecoNov08_Collisions11_JSON.txt,g' $CONFIG_COPY
    fi
fi

# Modify CMSSW config to read hltlist
if [[ ${FILE} == *"2011"* ]]; then
        sed -i -e 's,USEHLTLISTHERE,'${CMSSW_BASE}'/src/workspace/AOD2NanoAOD/data/HLT/HLT_Lepton_7TeV.txt,g' $CONFIG_COPY
    else
        sed -i -e 's,USEHLTLISTHERE,'${CMSSW_BASE}'/src/workspace/AOD2NanoAOD/data/HLT/HLT_Lepton_8TeV.txt,g' $CONFIG_COPY
fi

# Modify config to write output directly to EOS
sed -i -e 's,output.root,'${PROCESS}_${ID}.root',g' $CONFIG_COPY

# Print config
cat $CONFIG_COPY

# Run CMSSW config
cmsRun $CONFIG_COPY

# Copy output file
ls -trlh .
pwd
echo "COPY OUTPUT FILE ${PROCESS}_${ID}.root --> root://eosuser.cern.ch/${OUTPUT_DIR}/${PROCESS}/${PROCESS}_${ID}.root"
xrdcp -f ${PROCESS}_${ID}.root root://eosuser.cern.ch/${OUTPUT_DIR}/${PROCESS}/${PROCESS}_${ID}.root
rm ${PROCESS}_${ID}.root

echo "### End of job"
