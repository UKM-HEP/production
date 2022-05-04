#!/usr/bin/env python

import os
import sys

from gt import globaltag as GT

# https://batchdocs.web.cern.ch/tutorial/exercise9a.html
# https://htcondor.readthedocs.io/en/latest/users-manual/docker-universe-applications.html

#espresso     = 20 minutes
#microcentury = 1 hour
#longlunch    = 2 hours
#workday      = 8 hours
#tomorrow     = 1 day
#testmatch    = 3 days
#nextweek     = 1 week

#+JobFlavour = "longlunch"
#+MaxRuntime = 1800

# docker
jdl = """\
universe                = docker
docker_image            = docker.io/siewyanhoh/cmssw_5_3_32-condor
executable              = ./{PROCESS}.sh
output                  = out/$(ProcId).$(ClusterID).out
error                   = err/$(ProcId).$(ClusterID).err
log                     = log/$(ProcId).$(ClusterID).log
requirements            = OpSysAndVer =?= "CentOS7"
transfer_input_files    = AOD2NanoAOD.tgz, x509up
should_transfer_files   = YES
when_to_transfer_output = ON_EXIT
max_retries             = 3
request_memory          = 4000M
request_disk            = 4000000K
request_cpus            = 4
+MaxRuntime             = 1800
queue arguments from arguments.txt\
"""

# singularity
jdl2 = """\
universe                = vanilla
executable              = singularity_exec.sh
should_transfer_files   = YES
transfer_input_files    = AOD2NanoAOD.tgz, {PROCESS}.sh, x509up
when_to_transfer_output = ON_EXIT
output                  = out/$(ProcId).$(ClusterID).out
error                   = err/$(ProcId).$(ClusterID).err
log                     = log/$(ProcId).$(ClusterID).log
max_retries             = 3
request_memory          = 4000M
request_disk            = 4000000K
request_cpus            = 4
+JobFlavour             = "longlunch"
queue arguments from arguments.txt\
"""


def mkdir(path):
    if not os.path.exists(path):
        os.mkdir(path)


def parse_arguments():
    if not len(sys.argv) == 6:
        raise Exception("./create_job.py PROCESS PATH_TO_JOBDIR JOBTYPE GLOBALTAG COM")
    return {"process": sys.argv[1], "jobdir": sys.argv[2], "jobtype": sys.argv[3], "globaltag": sys.argv[4], "com": sys.argv[5]}


def main(args):
    process = args["process"]
    print("Process: %s" % process)

    datatype="DATA" if 'Run' in process else "MC"
    process_fn=""

    com = args["com"]
    # Build argument list
    print("Centre of Mass Energy : %s" %com)
    print("Filelist:")
    arguments = []
    counter = 0
    for filename in os.listdir("datasets/%s" %com):
        if process in filename:
            process_fn=filename
            print("    %s." % filename)
            for line in open("datasets/%s/%s" %(com,filename), "r").readlines():
                arguments.append("%u %s %s" % (counter, process, line))
                counter += 1
    print("Number of jobs: %u" % len(arguments))
    
    print("process_fn : ", process_fn)
    year= process_fn.split("_")[1][3:7] if datatype == "DATA" else process_fn.split("_")[1][-4:]
    gtkey=GT[year+"pp"][datatype]

    if com == "7TeV" or com == "8TeV":
        era="RunI"
    else:
        era="RunII"

    # Create jobdir and subdirectories
    jobdir = os.path.join(args["jobdir"], process)
    prod_name = args["jobdir"].split('/')[-1]
    print("Jobdir: %s" % jobdir)
    mkdir(jobdir)
    mkdir(os.path.join(jobdir, "out"))
    mkdir(os.path.join(jobdir, "log"))
    mkdir(os.path.join(jobdir, "err"))

    # Write jdl file
    out = open(os.path.join(jobdir, "job.jdl"), "w")
    out.write(jdl.format(PROCESS=process) if args["jobtype"] !="1" else jdl2.format(PROCESS=process))
    out.close()

    # Write argument list
    arglist = open(os.path.join(jobdir, "arguments.txt"), "w")
    for a in arguments:
        arglist.write(a)
    arglist.close()

    # Write job file
    jobfile = open("job.sh", "rt").read()
    jobfile = jobfile.replace('XX_U_XX', os.environ['USER'][0])
    jobfile = jobfile.replace('XX_USER_XX', os.environ['USER'])
    jobfile = jobfile.replace('XX_ERA_XX' , era )
    jobfile = jobfile.replace('XX_COM_XX' , com )
    jobfile = jobfile.replace('XX_PRODNAME_XX' , prod_name )
    if args["globaltag"] == "True": 
        jobfile = jobfile.replace('GT=\"None\"' , 'GT=\"%s\"' %gtkey )
        jobfile = jobfile.replace('XX_GLOBALTAG_XX' , gtkey )
    job = open(os.path.join(jobdir, "{PROCESS}.sh".format(PROCESS=process)), "w")
    job.write(jobfile)
    job.close()

    # copy the singularity execution file
    if args["jobtype"] == "1" :
        sexec = open("singularity_exec.sh", "rt").read()
        sexec = sexec.replace('XX_PROCESS_XX', process)
        execf = open(os.path.join( jobdir , "singularity_exec.sh" ), "w") 
        execf.write(sexec)
        execf.close()

        os.system("chmod +x %s" %(os.path.join(jobdir, "{PROCESS}.sh".format(PROCESS=process))) )

if __name__ == "__main__":
    args = parse_arguments()
    main(args)
