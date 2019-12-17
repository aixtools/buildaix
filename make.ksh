#!/usr/bin/ksh
#   Copyright 2012 -- Michael Felt
#
# $Revision:: 263                          $:  Revision of last commit
# $Author:: root                           $:  Author of last commit
# $Date:: 2017-10-03 18:09:28 +0000 (Tue, #$:  Date of last commit
# 
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# BUILDAIX.KSH - build myself!
# check for required fileset
# call a script to set environment variables
# call "configure" of project, or just run make if Makefile exists

cmd=$0
lslpp -L bos.adt.insttools >/dev/null || \
  (print "must have bos.adt.insttools installed" && exit 99)
[[ `id -u` -ne 0 ]] \
        && print "${cmd}: mkinstallp must be run with root authority" >&2 \
        && exit 97


# when packaing buildaix - always 32-bit mode!
unset OBJECT_MODE
cwd=`pwd`
PATH=${cwd}/opt/bin:${PATH}

unset vrmf
unset lpp

while getopts "-:V:P:F:h" opt; do
    case $opt in

    # INVALID
    :)
        print "${cmd}: Invalid syntax: -${OPTARG} needs an argument" > ${tty}
        error="error"
        exit 91
        ;;

    # print "${cmd}: Invalid option: -${opt}" > ${tty}
    \?)
        print "${cmd}: Invalid option: " > ${tty}
        error="error"
        exit 92
        ;;

    #specify Product of $Program.#PRODUCT.$Fileset name - override aixinfo
    P)
        PRODUCT=${OPTARG}
        export PRODUCT
        ;;

    #specify Fileset name - override aixinfo
    F)
        FILESET=${OPTARG}
        export FILESET
        ;;

    #specify VRMF number - override aixinfo
    V)
        v=${OPTARG}
        cnt=`echo ${v} | awk -F. ' { print NF } '`
        if [[ $cnt -eq 4 ]]; then
                VRMF=${v}
        else
                print -- ${v} is not a valid vrmf format
                exit -2
        fi
        unset v
        ;;
    esac
done

. opt/bin/aixinfo # set environment and installp variables

# my "install"
LPP=${PROGRAM}/${PRODUCT}
TEMPDIR=/var/tmp/${LPP}/${FILESET}/${VRMF}
export PROGRAM PRODUCT FILESET VRMF

rm -rf ${TEMPDIR}
mkdir -p ${TEMPDIR}
[[ $? -ne 0 ]] && print $cmd: cannot make TEMPDIR at $TEMPDIR && exit -1

# TODO - have .info directory in $TEMP_LPP
# for redirected output and to save template
rm -rf .buildaix
mkdir -p .buildaix

mkdir -p ${TEMPDIR}/opt/bin
for file in buildaix.ksh aixinfo mkinstallp.ksh mkXany mkX32 mkX64 cplib.ksh ; do
	cp -p opt/bin/$file ${TEMPDIR}/opt/bin
done

mkdir -p ${TEMPDIR}/usr/share/man/man1
for file in buildaix.1; do
	cp -p usr/share/man/man1/$file ${TEMPDIR}/usr/share/man/man1
done

mkdir -p ${TEMPDIR}/opt/buildaix/include
for file in bzlib.h zlib.h zconf.h; do
	cp -p opt/buildaix/include/$file ${TEMPDIR}/opt/buildaix/include
done

cp -rp opt/buildaix/templates ${TEMPDIR}/opt/buildaix/templates
rm -rf ${TEMPDIR}/opt/buildaix/templates/.svn

# mkinstallp does not accept links that begin with / and cannot be resolved immediately
# e.g., $TEMPDIR/opt/bin/buildaix.ksh exists, but not /opt/bin/buildaix.ksh
# and so the mkinstallp fails
# therefore, use relative names

mkdir -p ${TEMPDIR}/usr/bin
ln -s ../../opt/bin/buildaix.ksh $TEMPDIR/usr/bin/buildaix

print "# removing old buildaix - if still present, ignore error message - if any"
installp -u aixtools.buildaix >/dev/null
print -- "+-----------------------------------------------------------------------------+"

print "+ mkinstallp.ksh $TEMPDIR > .buildaix/mkinstallp.out"
opt/bin/mkinstallp.ksh $TEMPDIR | tee .buildaix/mkinstallp.out
[[ $? -ne 0 ]] &&
	print mkinstallp.ksh returned an error && tail .buildaix/mkinstallp.out && exit -1

# rm -rf $TEMPDIR

# list installable fileset(s)
print -- "+-----------------------------------------------------------------------------+"
# installp -d . -L
ls -l installp/ppc
print -- "+-----------------------------------------------------------------------------+"
