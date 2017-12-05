#!/usr/bin/ksh
#   Copyright 2012-2015 -- Michael Felt, aka AIXTOOLS
# $Date: 2017-09-21 12:28:21 +0000 (Thu, 21 Sep 2017) $
# $Revision: 251 $
# $Author: root $
# $Id: buildaix.ksh 251 2017-09-21 12:28:21Z root $
#

function do_flags
{
# determine MAKE - for now, if gmake can be found, assume MAKE==gmake,
# else check for /opt/bin/make, then whatever make returns
	type gmake 2>/dev/null
	if [[ $? -eq 0 ]]; then
		MAKE=gmake
	elif [[ -e /opt/bin/make ]]; then
		MAKE=/opt/bin/make
	else
		MAKE=make
	fi

	eprefix=${eprefix:=${prefix}}

	# assume if gcc is installed, vac flags are bad
	# assume if CC != cc is installed, additional vac flags are not wanted
	# thus, if CC=cc assume it is IBM C and add -qlanglvl=extc99
	# if CFLAGS are are not defined set optimization to level 3
	cflags=${CFLAGS:=-O2}

	# check for C compiler
	type gcc >/dev/null 2>&1
	found_gcc=$?
	type xlc >/dev/null 2>&1
	found_xlc=$?
	[[ $found_xlc -eq 0 ]] && CC=${CC:=xlc_r} && export CC \
           && cflags="${cflags} -qmaxmem=-1 -qarch=pwr5" \
           && [[ ${OBJECT_MODE} == "64" ]] && cflags="${cflags} -q64"

	# rpm.rte provides 3 core libraries - but dated
#
#	/usr/opt/freeware/lib/libz.a -v1.2.3
#	/usr/opt/freeware/lib/libintl.a -v-0.0.0
#	/usr/opt/freeware/lib/libbz2.a -v1.0.5
#
	# rpm.rte does not provide libz.h, zconf.h or bzlib.h
	# For here - if we cannot find zlib.h in standard locations
	# add our include directory to satisfy most requirements
	# if cannot find zlib.h then look at copy provided by buildaix
	## starting with buildaix-2.0.17 there are copies of these files
	## placed in /usr/include - to pacify most GNU expectations
	## and make the resulting CFLAGS more "fitting" for followup
	## e.g., some projects were seeing /opt/buildaix/include
	## added to default flags - when not necessary, nor needed.
        cppflags=0
        for file in zlib.h zconf.h bzlib.h; do
		[[ ! -e /usr/include/${file} && \
		   ! -e /usr/local/include/${file} && \
		   ! -e /opt/freeware/include/${file} ]] && \
		   [[ ! -e ${prefix}/include/${file} ]] && \
		   [[ ! -e ${eprefix}/include/${file} ]] && \
			cppflags=1
	done

	# (re-)define CFLAGS and add $prefix/include
	CFLAGS="-I${prefix}/include ${cflags}"
	# add $eprefix/include if different from $prefix
	[[ ${eprefix} != ${prefix} ]] && CFLAGS="-I${eprefix}/include $CFLAGS"
	[[ $cppflags -ne 0 ]] && CFLAGS="$CFLAGS -I/opt/buildaix/includes"
	export CFLAGS

	# some configure (buildconf results) do not find /opt/include
	# actually the buildconf familt of tools assume /usr and /usr/local and 
	# frequently skip the --prefix argument
	# adding /opt/include to CPPFLAGS solves most of these (maybe all)

	CPPFLAGS=${CPPFLAGS:=-I${PREFIX}/include}
	[[ ${eprefix} != ${prefix} ]] && CPPFLAGS="-I${eprefix}/include $CPPFLAGS"
	[[ $cppflags -ne 0 ]] && CPPFLAGS="$CPPFLAGS -I/opt/buildaix/include"
	export CPPFLAGS

} #end function do_pre_configure

function do_configure
{
# if Makefile already exists, skip calling config(ure)
if [[ -e ./Makefile ]]; then
	print $0: using existing Makefile
	print $0: run ${MAKE} distclean to get a standard AIX configure
	print
	ls -l ./Makefile config.*
	print
else
# TODO add --verbose flag checking
	do_flags
	# set eprefix if not same as prefix
	EPREFIX=""

	[[ ${prefix} != ${eprefix} ]] && \
		EPREFIX="--exec-prefix=${eprefix}"
# determine if the sources are current directory, or a sub-directory
# by finding configure. If in . assume all is here
. aixinfo
if test -e ./configure; then
	CONFIGURE="./configure"
elif test -e ../src/${DIRNAME}/configure; then
	CONFIGURE="../src/${DIRNAME}/configure"
else
	print $0: cannot find CONFIGURE
	exit -1
fi
	print "+ CPPFLAGS=\"${CPPFLAGS}\" CFLAGS=\"${CFLAGS}\"\\\\\n\
	${CONFIGURE}\\\\\n\
		--prefix=${prefix} ${EPREFIX}\\\\\n\
		--sysconfdir=/var/${FILESET}/etc\\\\\n\
		--sharedstatedir=/var/${FILESET}/com\\\\\n\
		--localstatedir=/var/${FILESET}\\\\\n\
		--mandir=/usr/share/man\\\\\n\
		--infodir=/opt/share/info/${FILESET} $cfgargs\\\\\n\
			> .buildaix/configure.out"

	CPPFLAGS="${CPPFLAGS}" CFLAGS="${CFLAGS}" ${CONFIGURE} \
		--prefix=${prefix} ${EPREFIX} \
		--sysconfdir=/var/${FILESET}/etc \
		--sharedstatedir=/var/${FILESET}/com \
		--localstatedir=/var/${FILESET} \
		--mandir=/usr/share/man \
		--infodir=/opt/share/info/${FILESET} $cfgargs \
			> .buildaix/configure.out
# VERBOSE stuff
	if [[ $? -ne 0 ]]; then
		print ${cmd}: '${CONFIGURE} ...' returned an error
		print ±±±±±±±±±±±±±±±±±±±
		set -x
		grep configure: config.log | tail
		set +x
		print ±±±±±±±±±±±±±±±±±±±
		print
		exit -1
	fi
fi
} # end do_configure

###########################

function do_aixinfo
{
# key variables returned determined are: PROGRAM, PRODUCT, FILESET, VRMF
# mkinstallp.ksh builds lpp and vrmf from these
# call aixinfo to set $PROGRAM $PRODUCT $FILESET $VRMF
if [[ -e buildaix/bin/aixinfo ]] ; then
	. buildaix/bin/aixinfo null 1
else
	type aixinfo >/dev/null
	[[ $? -ne 0 ]] && print ${cmd}: cannot find aixinfo && \
		print ${cmd}: you may need to add /opt/bin to your PATH && \
		print ${cmd}: exiting && exit -1
	. aixinfo
fi
} # end do_aixinfo

######### getopts processing #########
function do_getopts
{
cfgargs=""
# while getopts ....; do
while getopts "-:P:F:V:D:p:e:hfEUBT" opt; do
    case $opt in

    # add configure arguments to cfgargs
    -)
	[[ ! -z $cfgargs ]] && cfgargs="${cfgargs} --${OPTARG}"
	[[ -z $cfgargs ]] && cfgargs="--${OPTARG}"
        ;;

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
	FILESET=${FILESET:=${OPTARG}}
	export PRODUCT
	export FILESET
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

    # force configure call - cleanup and remove Makefile
    f)
	print "Force mode"
	[[ -e Makefile ]] && make -i distclean
	rm -f ?akefile config.*
	;;

    # copy directory and make it installable
    D)
	source="${OPTARG}"
	cwd=`pwd`
	# call aixinfo to set any missing arguments
	# aixinfo set these arguments, possible overwitten via P) F) V)
	do_aixinfo
# Bug in buildaix somewhere - setting a void lpp causes the lpp assignment to fail
# unset variable if zero length
[[ -z $lpp ]] && unset lpp

        if [ $PRODUCT == $PROGRAM ] || [ $PRODUCT == $FILESET ]; then
            lpp=${lpp-${PROGRAM}.${FILESET}}
        else
            lpp=${lpp-${PROGRAM}.${PRODUCT}.${FILESET}}
        fi
#       [[ $PRODUCT == $PROGRAM ]] && lpp=${lpp-${PROGRAM}.${FILESET}}
#       [[ $PRODUCT == $FILESET ]] && lpp=${lpp-${PROGRAM}.${FILESET}}
#       lpp=${lpp-${PROGRAM}.${PRODUCT}.${FILESET}}
        vrmf=${vrmf-${VRMF}}
	TARGETDIR=/var/${PROGRAM}/${PRODUCT}/${FILESET}/${VRMF}

	# clear
	cd ${source}
	print -- "#${cmd}:COPY/PASTE following commands to package the directory [`pwd`]"
	print -- "#${cmd}: proposal is:"
	cd ${cwd}
cat - <<EOF
# Part 0: FYI: these come from aixinfo
PROGRAM=${PROGRAM}
PRODUCT=${PRODUCT}
FILESET=${FILESET}
VRMF=${VRMF}


# Part 1 - copy to a clean directory
TARGETDIR=/var/${PROGRAM}/${PRODUCT}/${FILESET}/${VRMF}
rm -rf \${TARGETDIR}
mkdir -p \${TARGETDIR}
/usr/bin/cp -rph ${source}/* \${TARGETDIR}

# Part 2a - these variables are needed by mkinstallp for the template 
export lpp=${lpp}
export vrmf=${vrmf}

# Part 2b - build the installp files
print "+ mkinstallp.ksh \$TARGETDIR > .buildaix/mkinstallp.out"
mkinstallp.ksh \$TARGETDIR | tee  .buildaix/mkinstallp.out

# Part 2c - forget environment variables
print -- ## make sure they are removed from 'export' list
unset lpp
unset vrmf
### -- Finish
EOF
	exit 0
	;;

    p)      # install executables in subdirectory of ${prefix}
		print "PREFIX mode"
		prefix="${OPTARG}"
                # strip a trailing '/', if any
		prefix=`print -- ${prefix} | sed -e 's/\/$//'`

		;;

    e)      # install executables in subdirectory of ${prefix}/${OPTARG}
		print "EPREFIX mode: --eprefix=\$prefix/${OPTARG} added"
		eprefix="${OPTARG}"
		## maybe add this somewhere !
		## [[ ! -z ${EPREFIX} ]] && EPREFIX="--exec-prefix=/opt/${PRODUCT}/${FILESET}"
		eprefix=`print -- ${eprefix} | sed -e 's/\/$//'`
		;;

    E)      # install executables in subdirectory of /$prefix/${PRODUCT}/${FILESET}
		print "EPREFIX mode: --eprefix=\$prefix/${PRODUCT}/${FILESET} added"
		eprefix="\${prefix}/${PRODUCT}/${FILESET}"
		;;

    U)		# force UNSAFE mode for projects needing this
		export FORCE_UNSAFE_CONFIGURE=1
		print "export FORCE_UNSAFE_CONFIGURE=1"
		;;

    h)
        print "${cmd}: syntax: [-h] # this message - help" > ${tty}
        print "${cmd}: syntax: [-p prefix] [-E | -e exec-prefix] [-F] [--configure_args]" > ${tty}
        exit 1
        ;;

    B)	# initialize buildaix with copies of buildaix programs for package customization
		BAIX=${BASE}/buildaix/bin
		mkdir -p ${BAIX}
		for i in buildaix.ksh aixinfo mkinstallp.ksh; do
			[[ ! -e ${BAIX}/$i ]] && cp -p /opt/bin/$i ${BAIX} || (print "${cmd}: ${BAIX}/$i exists"; ls -l ${BAIX}/$i)
		done
		print copies of buildaix scripts in ${BAIX} for custom processing
		ls -l ${BAIX}
		exit 0
	;;

    T)	# initialize buildaix with templates
		T=/opt/buildaix/templates/fileset.ext
		README=/opt/buildaix/templates/README
		BUILDAIX=${BASE}/buildaix
		B=${BUILDAIX}/${FILESET}.rte
		R=${BUILDAIX}/root/${FILESET}.rte

		mkdir -p ${BASE}/buildaix/root

		cp -p ${README}.templates ${BUILDAIX}/README.${FILESET}.templates
		cp -p ${README}.cfgfiles  ${BUILDAIX}/README.${FILESET}.cfgfiles
		cp -p ${README}.override  ${BUILDAIX}/README.${FILESET}.override

		for i in pre_i post_i pre_rm unpre_i unpost_i ; do
			[[ ! -e ${B}.$i ]] && cp -p ${T}.$i ${B}.$i
		done
		for i in post_i pre_i config unconfig unpre_i unpost_i ; do
			[[ ! -e ${R}.$i ]] && cp -p ${T}.$i ${R}.$i
		done
		print customization script directories made
		print -- "+-----------------------------------------------------------------------------+"
		ls -lR buildaix
		print -- "+-----------------------------------------------------------------------------+"
		print remove scripts you are not planning on using.
		print remember ROOT installs last, but uninstalls first
		exit 0
        ;;
    esac
done

export lpp=${LPP}
export fset=${FILESET}
export vrmf=${VRMF}
} # end do_getopts
function do_make
{
	print "+ ${MAKE} > .buildaix/make.out"

        type gmake 2>/dev/null
        if [[ $? -eq 0 ]]; then
                MAKE=gmake
        elif [[ -e /opt/bin/make ]]; then
                MAKE=/opt/bin/make
        else
                MAKE=make
        fi

	${MAKE} > .buildaix/make.out
	[[ $? -ne 0 ]] && print "${MAKE}" returned an error && exit -1
} # end do_make

function do_make_target
{
# added for PHP builds as they are not fully GNU-standard
# Note: INSTALL_ROOT may not be defined earlier - due to side effects during regular make
	export INSTALL_ROOT=${TARGETDIR}

	rm -rf $TARGETDIR
	mkdir -p ${TARGETDIR}

	print "+ ${MAKE} install DESTDIR=$TARGETDIR > .buildaix/install.out"
	${MAKE} install DESTDIR=$TARGETDIR > .buildaix/install.out
	[[ $? -ne 0 ]] && print "${MAKE} install" returned an error && exit -1
} # end do_make_target

function do_mkinstallp
{
	# warn for required fileset
	status=0
	lslpp -L bos.adt.insttools >/dev/null
	if [[ $? -ne 0 ]] ; then
	    print "${cmd}:ERROR: bos.adt.insttools is required for mkinstallp" >&2
	    status = -1
	fi

	# must be root for mkinstallp
	if [[ `id -u` -ne 0 ]]; then
	    print "${cmd}:ERROR: mkinstallp: must be run with root authority"
	    status = -1
	fi

	[ ${status} -ne 0 ] && exit ${status}

	print -- "+ mkinstallp.ksh $TARGETDIR > .buildaix/mkinstallp.out"
	mkinstallp.ksh $TARGETDIR > .buildaix/mkinstallp.out
	if [[ $? -ne 0 ]]; then
		print ==============================
		print mkinstallp.ksh returned an error
		ls -ld ${TARGETDIR}
		ls -l ${TARGETDIR}
		ls -l .buildaix/*.out
		print ==============================
		exit -1
	fi

## TODO add a flag for --clean - cleaning is not default
[[ $clean -ne 0 ]] && rm -rf $TARGETDIR

## TODO --silent flag
# list installable fileset(s)
print ==============================
installp -d installp/ppc -L
print ==============================
} # end do_mkinstallp

########################## MAIN ##################
# defaults
# strip cmd to final part of command (in case relative path is used)
cmd0=$0
cmd=${cmd0##*/}
# arguments that might be passed to CONFIGURE later
cfgargs=$*

# default prefix is /opt
prefix=${prefix:="/opt"}

BASE=`pwd`
INFO=${BASE}/.buildaix

mkdir -p ${INFO}

# if a project script exists in ./buildaix/bin directory, execute that instead
if [[ ${cmd} == "buildaix" ]] && [[ -e ./buildaix/bin/buildaix.ksh ]]; then
	print executing ./buildaix/bin/buildaix.ksh
	exec ./buildaix/bin/buildaix.ksh $cfgargs
fi

# put localized aixinfo and/or mkinstallp first - and - what else?

export PATH=`pwd`/buildaix/bin:${PATH}

mkdir -p ./.buildaix
# key variables returned are: PROGRAM, PRODUCT, FILESET, VRMF, VRM and FIX

unset lpp
unset vrmf

do_getopts $cfgargs
do_aixinfo

lppdir=${PROGRAM}/${PRODUCT}/${FILESET}
TARGETDIR=/var/${PROGRAM}/${PRODUCT}/${FILESET}/${VRMF}

PREFIX=${PREFIX:=/opt}

# this if then else fi block is also experimental - here or above in getopt?
# prefer here, but with improved 'switching' logic
# for now - the 'then' part is 'normal' and runs, the else part reflects
# what is actually 'printed' above (as the exit above prevents ever getting here)
if [[ -z ${source} ]]; then
	do_configure
	do_make
	do_make_target
else
# this was to complete a copy operation, instead, it should not happen
	print "ERROR - should not be here!"
	exit -17
fi

# so-called 'normal' processing continues from here

do_mkinstallp
