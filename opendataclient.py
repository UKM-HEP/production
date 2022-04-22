import os, subprocess
from subprocess import PIPE, Popen
from catalogue import datasets

cwd = os.getcwd()

DOCKER_IMAGE="siewyanhoh/cmssw_5_3_32:1.0" # cmsopendata/cmssw_5_3_32-slc6_amd64_gcc472

for ientry in datasets:
    handle= '--title '+ientry if not datasets[ientry]['data'] else '--doi '+datasets[ientry]['doi'].split('http://doi.org/')[-1]

    # Query
    cmd='docker run -i -t --rm cernopendata/cernopendata-client get-metadata %s --output-value files' %( handle )
    cmdtxt=cmd+' | grep _file_index.txt'
    listdict = subprocess.check_output(cmdtxt, shell=True).splitlines()
    files = list(map( lambda x : x.decode("utf-8").strip() , listdict ))
    files = list(filter( lambda x : 'uri' in x , files ))

    # Copy
    xrdcp = 'docker run --privileged -v ${PWD}/samples:/eos:rw -i --rm %s xrdcp' %( DOCKER_IMAGE ) if 'CMSSW_' not in cwd else 'xrdcp'
    for ifile in files:
        cmdcpy='%s %s /eos' %( xrdcp , ifile.replace("\"","").split("uri: ")[-1] )
        print(cmdcpy)
        os.system( cmdcpy )
