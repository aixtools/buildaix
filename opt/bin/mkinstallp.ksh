#!/usr/bin/ksh
#   Copyright 2012-2020 -- Michael Felt, AIXTOOLS
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
#
# minstallp.ksh # create a template file (and copy additional configfiles)
# that will be used by /usr/bin/mkinstallp and /usr/sbin/makebff.pl
# to create an installp package
# Requires bos.adt.insttools

# fatal: list ${TMP} contents, the template (as far as it exists) and exit
function fatal
{
	typeset _status _cmd _msg
	_cmd=$1
	_status=$2
	_msg=$3
	print $cmd:$_cmd: ++++++ DEBUG ++++++
	print $cmd:$_cmd: $_msg
	[[ -d ${TMP} ]] && print && ls -ltr ${TMP} $template
	print $cmd: ++++++ DEBUG ++++++
	exit $_status
}

# get_lpp_vrmf: call utility aixtools
# as well as set env vars: PROGRAM PRODUCT FILESET VRMF
# these are used to set lpp and vrmf - if not already defined
function get_lpp_vrmf
{
	[[ -z $BASEDIR ]] && fatal $0 3 "BASEDIR Directory not defined"

	cd ${BASEDIR}
	. aixinfo
	[[ -x ./buildaix/bin/aixinfo ]] &&\
		. ./buildaix/bin/aixinfo && print overwriting AIXINFO variables using build/aix/aixinfo

	# define ${lpp} and ${vrmf}
	# if variables are zero length - unset them
	[[ -z ${lpp} ]] && unset lpp
	[[ -z ${vrmf} ]] && unset vrmf

	if [ $PRODUCT == $PROGRAM ] || [ $PRODUCT == $FILESET ]; then
	    lpp=${lpp-${PROGRAM}.${FILESET}}
	else
	    lpp=${lpp-${PROGRAM}.${PRODUCT}.${FILESET}}
	fi
	vrmf=${vrmf-${VRMF}}
}

# set_ugid_access
# set user.group of files to bin:bin
# remove group and other write perms
# add directory access bit to other
# These values are what will go into the .inventory
# NOTE: exceptions must be managed elsewhere
function set_ugid_access
{
	# set all to bin:bin rather than root:system
	typeset _uid _gid _pwd
	_uid=$1
	_gid=$2
	[[ -z $_uid ]] && _uid="bin" 
	[[ -z $_gid ]] && _gid="bin" 
	
	_pwd=${PWD}
	cd ${LPPBASE}/..
	[[ ${PWD} == "/" ]] && fatal $0 6 "$LPPBASE may not be \"/\""
	[[ -z $INST_FILES ]] && fatal $0 4 "INST_FILES is zero length"
	[[ ! -d $INST_FILES ]] && fatal $0 5 "$INST_FILES is not a directory of ${LPPBASE}"
	chown -R ${_uid}:${_gid} ${INST_FILES}

	# all files and directories are readable by all, no group write
	chmod -R go+r,go-w ${INST_FILES}

	# all directories are accessible by default
	find ${INST_FILES} -type d -exec chmod og+x {} \;
	cd ${_pwd}
}

# lpp_info_reset
# clear out old information incase a repeat install
function lpp_info_reset
{
	typeset _cwd
	_cwd=${PWD}
	[[ -z $LPPBASE ]] && print $cmd: $0 -- envp LPPBASE must be defined && exit -1
	cd ${LPPBASE}
	[[ $? != 0 ]] && print $cmd: $0 -- cannot chdir to directory ${LPPBASE} && exit -1

	CONFIGDIR=${LPPBASE}/.info
	[[ -e ${CONFIGDIR} ]] && print "$cmd: $0 -- ${CONFIGDIR} should not exist - removing" && rm -rf ${CONFIGDIR}
	[[ -e ${CONFIGDIR} ]] && echo ${cmd}: cleanup error && pwd && ls -la && exit -1
	mkdir ${CONFIGDIR}
	[[ ! -d ${CONFIGDIR} ]] && print "${cmd}: $0 - cannot make new ${CONFIGDIR}" && exit -1
	cd ${_cwd}
}

# remove control directories from a previous install, if any
function lpp_reset
{
	typeset LPPBASE _cwd
	_cwd=${PWD}
	# LPPBASE is a pseudo-root as far as packaging is concerned. It must exist!
	LPPBASE=$1
	[[ -z $LPPBASE ]] && print $cmd: $0 -- LPPBASE must be defined && exit -1
	cd ${LPPBASE}
	[[ $? != 0 ]] && print $cmd: $0 -- cannot chdir to directory ${LPPBASE} && exit -1

	lpp_info_reset

	# remove other possible files
	rm -rf lpp_name tmp usr/lpp
	[[ $? -ne 0 ]] && echo ${cmd}: cleanup error && pwd && ls -la && exit -1

	# clean up side-effects from DEBUG passes - usr/local might be there as
	# mkinstallp/makebff.pl create symbolic links when certain directories do not exist
	# this may create circular links during the template creation phase
	# e.g., usr/local points at /usr/local
	# as we are not using /usr/local for packaging, remove it!

	# if any of the following directories are links - remove them
	[[ -L etc ]] && rm -f etc && echo removed unexpected symbolic link at ${PWD}/etc !!^G
	[[ -L var ]] && rm -f var && echo removed unexpected symbolic link at ${PWD}/var !!^G
	[[ -L opt ]] && rm -f opt && echo removed unexpected symbolic link at ${PWD}/opt !!^G
	[[ -L usr/local ]] && rm -f usr/local && echo removed unexpected symbolic link at ${PWD}/usr/local !!^G

	cd ${_cwd}
}

# filename_verification
# filenames must be free of certain characters that break later processing
# by default processing
# we cannot have files with = : or , in the name, changing the name if needed - documented
# we cannot have files with [ ( or ) in the name, changing the name if needed - documented
# this function should report an error - as special file names should be dealt with
# via prep_install.ksh and further processing by .post_i and .pre_d (or *.config*)
## the file ${DOTBUILD}/moved can be used to automate processing in .config, .unconfig
function filename_verification
{
	typeset _pwd
	_pwd=${PWD}
	cd ${LPPBASE}
	> ${DOTBUILD}/moved	# be sure file exists and is 0 bytes
	find . | /usr/bin/egrep "\[|\(|\)|:|=|,| " | while read old
	do
		new=`echo ${old} | sed -e 's/[\[\(\):,= ]\{1,9\}/_/g'`
		if [[ ! -z ${VERBOSE} ]]; then
			print renamed:${old}:${new} | tee -a ${DOTBUILD}/moved
		else
			print renamed:${old}:${new} >>${DOTBUILD}/moved
		fi
		mv -- "${old}" ${new}
	done
	cd ${_pwd}
}

# init_lppbase - Initialize globals
function init_lppbase
{
	# set globals
	today=$(date -u +"%d-%b-%Y")
	LPPBASE=$1
	BASEDIR=${PWD}
	# tempfiles in project area
	DOTBUILD=${BASEDIR}/.buildaix
	# configfile sources and template result
	BUILDAIX=${BASEDIR}/buildaix
	# makebff (like) CONFIGDIR
	CONFIGDIR=${LPPBASE}/.info
	PID=$$
	TMP=/tmp/buildaix.${PID}
	umask 022

	# get PROGRAM PRODUCT FILESET VRMF and set lpp and vrmf
	get_lpp_vrmf
	INST_FILES=./${vrmf} 	# relative path!
	template=${BUILDAIX}/${lpp}.${vrmf}.template

	# make sure LPPBASE is clean
	lpp_reset ${LPPBASE}

	mkdir -p ${DOTBUILD} ${BUILDAIX}
	rm -f ${template}
	touch ${template}
	[[ ! -w ${template} ]] && fatal $0 1 "cannot create template: $template"
	# let's be sure we are back in BASEDIR
	cd ${BASEDIR}
	rm -rf ${TMP}; mkdir -p ${TMP}
	[[ ! -d ${TMP} ]] && fatal $0 2 "cannot create TMP as ${TMP}"
}

function lpp_prepfiles
{
	PREP=${BASEDIR}/buildaix/bin/prep_install.ksh
	cd ${LPPBASE}
	# Nearly every GNU package (that uses libiconv adds this file - needs a unique name
	# TBD - helper script to add a symbolic link to opt/lib/charset.alias if it does not "resolve"
	[[ -e opt/lib/charset.alias ]] && mv  opt/lib/charset.alias  opt/lib/charset.alias.${PRODUCT}.${FILESET}

	# special files are README, COPYRIGHT, LICENSE, CHANGELOG
	# copy to DOTBUILD if not already present - for later processing
	# 'prep_special_files' - maybe taken care of by lpp_extra_files ?
	# prep_special_files

	# set owner of INST_FILES to root:system and remove group and other write perms
	# if specific group/other write perms must be set, that needs to be managed in a post_i script
	set_ugid_access

	# Do AIX link processing - call ${BASEDIR}/buildaix/bin/aixlinks
	# making links here - rather than in a config script gets them into the applyList
	# TODO - aka - maybe I prefer using config/unconfig scripts - more control!
	# mk_aixlinks

	# if project needs to do some special processing (e.g., move configure files)
	# before applyList processing - call prep_install.ksh to do it!
	[[ -e ${PREP} ]] && \
		print "++ PREP INSTALL ++" && ${PREP} ${LPPBASE} ${PROGRAM}.${PRODUCT}.${FILESET}

	filename_verification

	cd ${BASEDIR}
}

# do requisite processing per fileset extension
# if there is not a stanza, or no requisites file at all
# just return
# example
#rte:
#	prereq aixtools.gnu.gettext.rte 0.18.0.0
#	prereq aixtools.gnu.gettext.share 0.18.0.0
#
function lpp_requisites
{
    typeset ext vrmf
    ext=$1
    [[ ! -e ${BUILDAIX}/requisites ]] && return
    /usr/bin/grep -p ${ext}: ${BUILDAIX}/requisites > /dev/null
    [[ $? -ne 0 ]] && return

    # seems we have something, so lets process it
    touch ${DOTBUILD}/requisites.${ext}
    /usr/bin/grep -p ${ext}: ${BUILDAIX}/requisites | /usr/bin/egrep -v "^${ext}:$|^$" | \
	while read fileset vrmf type; do
		if [[ "$fileset" == ">"*  || "$fileset" == "}"* ]]; then	# group requisite
			print "$fileset $vrmf $type" >> ${DOTBUILD}/requisites.${ext}
			continue
		fi
		[[ -z $fileset ]] && continue # just in case a 'blank' line is not empty
		if [[ -z $vrmf ]]; then
			vrmf=`lslpp -Lqc $fileset | /usr/bin/grep $fileset | awk -F: ' { print $3 } ' | head -1`
		fi
		[[ -z $type ]] && type="prereq"
		print "*$type $fileset $vrmf" >> ${DOTBUILD}/requisites.${ext}
	done
}

# Make fileset ApplyLists
# create the list of files for the named fileset
# extract these files from the global list - so they are not installed multiple times
function mk_fileset_al
{
# By design "/opt/share" will never be included in the inventory - so it's uid.gid will be 0.0
	rexp=$1
	name=$2
	# extract what I am looking for to ${name}.al - rexp must be a directory
	/usr/bin/egrep "${rexp}/" ${TMP}/1.al > ${TMP}/${name}.al
	# remove what I found
	/usr/bin/egrep -v "${rexp}/" ${TMP}/1.al > ${TMP}/2.al
	# remove the directory base withoout the / ending
	/usr/bin/egrep -v "${rexp}$" ${TMP}/2.al > ${TMP}/1.al
	rm -f ${TMP}/2.al
}

# mk_fileset_adt
# create the list of files for the adt fileset (Application Development Tools)
function mk_fileset_adt
{
	rexp=$1
	name=$2
	# extract what I am looking for to ${name}.al - rexp must be a directory
	/usr/bin/egrep "${rexp}/" ${TMP}/1.al | /usr/bin/egrep -v "${rexp}/.*/" > ${TMP}/${name}.al
	# remove what I found
	/usr/bin/egrep "${rexp}/.*/" > ${TMP}/2.al
	/usr/bin/egrep -v "${rexp}/" ${TMP}/1.al >> ${TMP}/2.al
	# remove the directory base withoout the / ending
	/usr/bin/egrep -v "${rexp}$" ${TMP}/2.al > ${TMP}/1.al
	rm -f ${TMP}/2.al
}

# create the global applyList - make sure that .info is not included
function create_global_al
{
# convention is that the LPPBASE always ends with ${vrmf}
	cd ${LPPBASE}/..
	# INST_FILES=./${vrmf} 	# relative path!
	[[ -z $INST_FILES ]] && fatal $0 -1 "INST_FILES is zero length"
	# list all files in install_root, striping names of unwanted prefix
	# also skip[ any blank lines and directory names (ending with / character)
	find ${INST_FILES} | sed -e s#^${INST_FILES}## | sed -e "/^$/d" | sed -e "/^\/$/d" >${TMP}/0.al

	# remove .info/* from .al (ApplyList)
	/usr/bin/egrep -v "^/.info" ${TMP}/0.al > ${TMP}/1.al
	# .0 is global, unmodified list for debugging
	# .1 is global, applylist
	mv ${TMP}/0.al ${TMP}/debug.al
}

# lpp_extra_files
# these are not fileset dependent - so no arguments
# There are extra control files that makebff.pl recognizes
# but are not processed by the mkinstallp template
# This routine suplements /usr/sbin/mkinstallp processing
function lpp_extra_files
{
	LAR=""
	LAF_FILE=""
	LAF_INCLUDED="N"
	LPP_SPECIAL="N"
	[[ -z $FILESET ]] && fatal $0 -1 "need FILESET to be defined"
	for file in COPYRIGHT LICENSE README CHANGELOG
	do
		[[ ! -r ${BASEDIR}/$file ]] && continue
		case $file in
			"COPYRIGHT")
				cp -p ${BASEDIR}/$file ${DOTBUILD}/$lpp.copyright
				if [[ ${AIXV} == "5" ]]; then
				  LPP_SPECIAL="Y"
				fi
			  ;;
			"README")
				LPP_SPECIAL="Y"
				cp -p ${BASEDIR}/$file ${DOTBUILD}/lpp.README
			  ;;
			"CHANGELOG")
				LPP_SPECIAL="Y"
				cat ${DOTBUILD}/lpp.README >${TMP}/lpp.README 
				print "+----- ----- ----- ----- ----- ----- ----- ----- ----- ----- -----+" >> ${TMP}/lpp.README
				cat ${BASEDIR}/$file >> ${TMP}/lpp.README
				cat ${TMP}/lpp.README >${DOTBUILD}/lpp.README
				rm -f ${TMP}/lpp.README
			  ;;
			"LICENSE")	# license agreement file
				# do not need to set LPP_SPECIAL because LAF is handled by mkinstallp
				# copy LICENSE information if available to swlag
				cp -p ${BASEDIR}/LICENSE ${DOTBUILD}/${lpp}.la
				chown bin:bin ${DOTBUILD}/${lpp}.la
				chmod a+r ${DOTBUILD}/${lpp}.la
				mkdir -p ${LPPBASE}/usr/swlag/en_US
				cp -p ${DOTBUILD}/${lpp}.la ${LPPBASE}/usr/swlag/en_US/${lpp}.la
				LAF_FILE="LAF<en_US>/usr/swlag/en_US/${lpp}.la"
				# LAR_FILE="LAR/usr/swlag/%L/${lpp}.la"
				LAR_FILE="LAR/usr/swlag/en_US/${lpp}.la"
				LAF_INCLUDED="Y"
			  ;;
			*) ;;
		esac
	done
}

#lpp_extra_cfg - process optional config files that makebff.pl can also process
# skipping the one mkinstallp is already processing!
# # as mkinstallp also clears .info we cannot copy directly to $CONFIGDIR
# # if we have any files - they are copied after the dummy makebff.pl is called
# my @configFiles=(
#   "al","cfginfo","cfgfiles","config","config_u","copyright","err","fixdata",
#   "inventory","namelist","odmadd","odmdel","post_i","post_u","pre_d","pre_i",
#   "pre_rm","pre_u","productid","README","rm_inv","size","trc","unconfig","unconfig_u",
#   "unodmadd","unpost_i","unpost_u","unpre_i","unpre_u"
# );
# 
# cfginfo: special instructions - only one - BOOT - not used
# cfgfiles: user-configureable files
# copyright: copyright message
# err: template file used as input to errupdate
# fixdata: info about the update - not used atm
# imventory: contains required software vital product data for the files in fileset
# namelist: obsolete filesets - not used
# odmadd: stanzas to be added to ODM
# rm_inv: remove inventory - This file is for installation of repackaged software products only
# size: space requirements - managed by mkinstallp
# README: aka lpp.README
# productid: Product Identification file # not used
# 
# Optional 'executitional'
# config, config_u: by template
# odmdel: update ODM before adding new ODM entries
# pre_d: by template
# pre_i, pre_u: by template
# pre_rej: by template
# pre_rm: by template
# post_i, post_u: by template
# unconfig, unconfig_u: by template
# unpre_i, unpre_u: by template
# unconfig_d: by template (if exists, overrides unconfig, unconfig_i and unpre_i)
function lpp_extra_cfg
{
  typeset infile base cfg action _dir _cfgdir _ext
  infile=$1
  _dir=$2
  _cfgdir=${DOTBUILD}/${_dir}
  _ext="rte"
  mkdir -p ${_cfgdir}
  base=$(basename $infile)
  for cfg in "cfginfo" "cfgfiles" "copyright" "err" "fixdata" "inventory" "namelist" "odmadd" "odmdel" "override" "productid" "README" "rm_inv" "size" "trc" "unodmadd" ; do
	[[ ! -r $infile.$cfg ]] && continue
	case $cfg in
	  "cfgfiles")
	    CFG_FILES="Y"	# One or more config files
	    #debugging print $infile.$cfg " -> " ${_cfgdir}/${lpp}.$ext.$cfg
	    cp -p $infile.$cfg ${_cfgdir}/${lpp}.$ext.$cfg
	    ;;
	  "copyright")
	    [[ ! -r ${DOTBUILD}/$lpp.copyright ]] && continue
	    #debugging print $lpp.copyright " -> " ${_cfgdir}/$lpp.copyright
	    if [[ ${AIXV} == "5" ]]; then
	      LPP_SPECIAL="Y"
	      CFG_FILES="Y"	# One or more config files
	      cp -p ${DOTBUILD}/$lpp.copyright ${_cfgdir}/$lpp.copyright
	    # else
	    #   print "Copyright file path:  ${DOTBUILD}/$lpp.copyright" >> $template
	    fi
	    #debugging print $infile.$cfg " -> " ${_cfgdir}/$base.$cfg
	    cp -p $infile.$cfg ${_cfgdir}/$base.$cfg
				cp -p ${BASEDIR}/$file ${DOTBUILD}/$lpp.copyright
	    ;;
	  "override")
	    [[ ${AIXV} == "5" ]] && continue
	    CFG_FILES="Y"	# One or more config files
	    #debugging print $base.$cfg " -> " ${_cfgdir}/$lpp.$base.$cfg
	    cp -p $infile.$cfg ${_cfgdir}/${lpp}.$base.$cfg
	    ;;
	  "README"  |\
	  "cfginfo" |\
	  "err" |\
	  "fixdata" |\
	  "inventory" |\
	  "namelist" |\
	  "odmadd" |\
	  "odmdel" |\
	  "productid" |\
	  "rm_inv" |\
	  "size" |\
	  "trc" |\
	  "unodmadd")
	    ;;
	  *)
	    fatal $0 -1 "error: $infile $cfg !"
	    ;;
	esac
  done
  # [[ ${CFG_FILES}=="Y" ]] && ls -l ${_cfgdir}
}

function lpp_file
{
# if file exists then append line to template
	typeset lpp cfg keyword
	baselpp=$1
	cfg=$2
	file="$baselpp.$cfg"
	keyword="$3"
	[[ ! -r ${file} ]] && return;
	print "  ${keyword}: ${file}" >>${template}
}

function mk_fileset
{
#          "Fileset Name"
#          "Fileset VRMF"
#          "Fileset Description"
#          "Copyright file path"  )      CPRGHT_PATH=${REST_FILESET_LINE#[ ]*}   ;;
#          "ROOTLIBLPPFiles"      )      parse_rootlpp_files                     ;;
#          "Bosboot required"     )      BOSBOOT=${REST_FILESET_LINE#[ ]*}       ;;
#          "License agreement acceptance required"  )
#                                        LIC_REQUIRED=${REST_FILESET_LINE#[ ]*}  ;;
#          "Name of license agreement" )
#                                        LAR=${REST_FILESET_LINE#[ ]*}           ;;
#          "Include license files in this package"  )
#                                        LIC_INCLUDED=${REST_FILESET_LINE#[ ]*}  ;;
#          "License file path"    )      LAF=${REST_FILESET_LINE#[ ]*}           ;;
#          "Requisites"           )      REQUISITES=${REST_FILESET_LINE#[ ]*}    ;;
#          "Upsize"               )      ADD=${REST_FILESET_LINE#[ ]*}           ;;
#          "USRFiles"             )      parse_usr_files                         ;;
#          "ROOT Part"            )      CREATE_ROOT=${REST_FILESET_LINE#[ ]*}   ;;
#          "ROOTFiles"            )      parse_root_files                        ;;
#          "Relocatable"          )      RELOC=${REST_FILESET_LINE#[ ]*}         ;;
#          "Requisites_r"         )      REQUISITES_R=${REST_FILESET_LINE#[ ]*}  ;;
#          "OVERRIDE_INVENTORY"   )      OIF_PATH=${REST_FILESET_LINE#[ ]*}      ;;
#          "WPAR_sys"             )      WPAR_ATTR_SYSTEM=${REST_FILESET_LINE#[ ]*}       ;;
#          "WPAR_priv"            )      WPAR_ATTR_PRIVATE=${REST_FILESET_LINE#[ ]*}      ;;
	a=1
}

# Note 7: The override inventory file needs to have the same structure as a normal
#       inventory file.  The path of this file (if it exists) needs to be specified in the
#       OVERRIDE_INVENTORY line in the template as shown in example 6 (/tmp/inv1).
#       With this file, we intend to change the value of owner, group, mode, size and checksum
#       fields of a file stanza as it is needed for user configurable files.
#       The user can specify any value in owner, group and mode.
#       For the size and checksum, the user can set up its value to VOLATILE only.
#       If the user does not set both values (size and checksum) fields with the
#       VOLATILE value in the override inventory file, the system will use the system
#       values for the size and checksum fields for a given stanza.
#       The user needs to provide stanza like the example below for each file that needs to be
#       modified with the VOLATILE value (/usr/bin/file1, /usr/bin/file2) and owner, group and
#       mode fields (usr/bin/file3):

#       /usr/bin/file1:
#         owner =
#         group =
#         mode =
#         type =
#         class =
#         size = VOLATILE
#         checksum = VOLATILE

#       /usr/bin/file2:
#         owner =
#         group =
#         mode =
#         type =
#         class =
#         size = VOLATILE
#         checksum = VOLATILE

#       /usr/bin/file3:
#         owner = pdadmin
#         group = system
#         mode = 777
#         type =
#         class =
#         size =
#         checksum =


	# do LIBLPP processing here
	# this will - later include both start text USRLIBLPPFiles as finish EOUSRLPBLPPFiles
#       case $FILE_KEYWORD in
#             "Pre_rm Script"        )      PRERM_PATH=${REST_FILE_LINE#[ ]*}    ;;
#             "Pre-installation Script" )   PRE_PATH=${REST_FILE_LINE#[ ]*}      ;;
#             "Pre-deinstall Script" )      PRED_PATH=${REST_FILE_LINE#[ ]*}  ;;
#             "Unpre-installation Script" ) UNPRE_PATH=${REST_FILE_LINE#[ ]*}    ;;
#             "Post-installation Script")   POST_PATH=${REST_FILE_LINE#[ ]*}     ;;
#             "Unpost-installation Script") UNPOST_PATH=${REST_FILE_LINE#[ ]*}   ;;
#             "Configuration Script")       CONFIG_PATH=${REST_FILE_LINE#[ ]*}   ;;
#             "Unconfiguration Script")     UNCONFIG_PATH=${REST_FILE_LINE#[ ]*} ;;
#       esac
function rootlpp_files
{
typeset ext=$1
typeset B=${BUILDAIX}/root/${FILESET}.${ext}
print "  ROOTLIBLPPFiles" >> $template

	lpp_file $B config     "Configuration Script"
	lpp_file $B pre_rm     "Pre_rm Script"
	lpp_file $B pre_i      "Pre-installation Script"
	lpp_file $B post_i     "Post-installation Script"
	lpp_file $B unconfig   "Unconfiguration Script"
	lpp_file $B unpre_i    "Unpre-installation Script"
	lpp_file $B unpost_i   "Unpost-installation Script"
	if [[ ${AIXV} != "5" ]]; then
		lpp_file $B override   "OVERRIDE_INVENTORY"
		lpp_file $B copyright   "Copyright file path"
	fi
	# Above are all handled in the template
	# Below are handled by makebff.pl - if they live in the right area
        lpp_extra_cfg $B root

print "  EOROOTLIBLPPFiles" >> $template
}

#          "USRLIBLPPFiles"       )
	# do LIBLPP processing here
	# this will - later include both start text USRLIBLPPFiles as finish EOUSRLPBLPPFiles
#       case $FILE_KEYWORD in
#             "Pre_rm Script"        )      PRERM_PATH=${REST_FILE_LINE#[ ]*}    ;;
#             "Pre-installation Script" )   PRE_PATH=${REST_FILE_LINE#[ ]*}      ;;
#             "Pre-deinstall Script" )      PRED_PATH=${REST_FILE_LINE#[ ]*}  ;;
#             "Unpre-installation Script" ) UNPRE_PATH=${REST_FILE_LINE#[ ]*}    ;;
#             "Post-installation Script")   POST_PATH=${REST_FILE_LINE#[ ]*}     ;;
#             "Unpost-installation Script") UNPOST_PATH=${REST_FILE_LINE#[ ]*}   ;;
#             "Configuration Script")       CONFIG_PATH=${REST_FILE_LINE#[ ]*}   ;;
#             "Unconfiguration Script")     UNCONFIG_PATH=${REST_FILE_LINE#[ ]*} ;;
#       esac
function usrlpp_files
{
typeset ext=$1
typeset B=${BUILDAIX}/${FILESET}.${ext}
print "  USRLIBLPPFiles" >> $template

	lpp_file $B config     "Configuration Script"
	lpp_file $B pre_rm     "Pre_rm Script"
	lpp_file $B pre_i      "Pre-installation Script"
	lpp_file $B post_i     "Post-installation Script"
	lpp_file $B unconfig   "Unconfiguration Script"
	lpp_file $B unpre_i    "Unpre-installation Script"
	lpp_file $B unpost_i   "Unpost-installation Script"
	if [[ ${AIXV} != "5" ]]; then
		lpp_file $B override   "OVERRIDE_INVENTORY"
		lpp_file $B copyright   "Copyright file path"
	fi
	# Above are all handled in the template
	# Below are handled by makebff.pl - if they live in the right area
        lpp_extra_cfg $B user
print "  EOUSRLIBLPPFiles" >> $template
}

function do_upsize
{
# get the directory sizes in blocks
# du | sort -k 2 | /usr/bin/grep "/" | head | awk ' { print " Upsize:", $2, $1 ";"} ' | cut -c 2- 
# for some dir do the dir and it subdirs
# du | /usr/bin/egrep -v "^0" | /usr/bin/grep "./" | sort -k 2 | awk ' { print " Upsize:", $2, $1 ";"} ' | cut -c 2- 
dirlist=$1
[[ -z ${dirlist} ]] && dirlist="etc opt var"

for dir in ${dirlist}
do
	if [[ -d ${dir}/${FILESET} ]]
	then
		set `du -s ${dir}/${FILESET}`
                let szdir=$1+1
                echo "      Upsize: $2 ${szdir};" >> $template
	fi
	# make sure the argument exists before using setting values
	if [[ -d ${dir} ]]
	then
		set `du -s ${dir}`
                let szdir=$1+1
                echo "      Upsize: $2 ${szdir};" >> $template
	fi
done
}

function do_requisites_ext
{
#
#	CONFIG_PATH=.config_i
#	POST_PATH=.post_i
#	PRE_PATH=.pre_i
#	PRERM_PATH=.pre_rm
#	UNPRE_PATH=.pre_d
#	UNPOST_PATH=.post_d
#	UNCONFIG_PATH=.config_d
#	OVERRIDE_INVENTORY

        B=${BASEDIR}/buildaix/${FILESET}.rte
}

function add_bos_prereq
{
# add a Requisite for at least the current libc fileset - to prevent installing AIX 6.1 on AIX 5.3, etc.
RTEVRML=`lslpp -Lqc bos.rte.libc | awk -F: ' { print $3 } '|sed s/[0-9]*$/0/'`
AIXVER=`echo ${RTEVRML} | awk -F. '{print "aix" $1 $2 $3}'`
}

function init_template
{
	cat - <<EOF >${template}
Package Name: ${lpp}
Package VRMF: ${vrmf}
Update: N
EOF
}

# add_fileset "^/(opt|usr)/share/man" "man" "man pages" "*/share/man"
function add_fileset
{
	typeset expression extension label fileset du_sizes
# expression is the string that we look for in the (remaining) global inventory
#  to make the "fileset" file .al aka applyList
# entension is the fileset extension (e.g., man, share)
# 
	expression=$1
	extension=$2
	label=$3
	du_sizes=$4

        cd ${LPPBASE}
	mk_fileset_al ${expression} ${extension}
	# if there are files to be included - include them!
        if [[ -s ${TMP}/${extension}.al ]]
        then
	    if [[ $PRODUCT != ${FILESET} ]]; then
		descr="${PRODUCT} ${FILESET} ${label}"
	    else
		descr="${PRODUCT} ${label} ${ts}"
	    fi

	    fileset=${lpp}.${extension}
	    [[ ${extension} == "man" ]] && fileset=${fileset}.en_US
	    cat - <<EOF >>$template
Fileset
  Fileset Name: ${fileset}
  Fileset VRMF: ${vrmf}
  Fileset Description: ${descr}
EOF
	    usrlpp_files ${extension}
# the next keywords are required by /usr/sbin/mkinstallp - so provided with defaults
# to work with license files, license acceptance - defaults here - see 'rte' block
	    cat - <<EOF >>$template
  Bosboot required: N
  License agreement acceptance required: N
  Name of license agreement: 
  Include license files in this package: N
EOF
## TODO - add instreq for man pages and coreq for other filesets
##  if [[ ${extension} == "man" ]]; then
##   print -- "Requisites: *instreq ${lpp}.rte ${vrmf}"
##  else
##   print -- "Requisites: *coreq ${lpp}.rte ${vrmf}"
##  fi
## TODO ## process Requisites rather than leave blank
## as only .rte has requisites processing
            do_upsize $du_sizes
	    echo "  USRFiles" >> $template
	
## this needs to be modified so that it only scans valid files
## for now just skip /opt/share and we are good
####cd ${LPPBASE}/..

	    cat ${TMP}/${extension}.al >>${template}
	
# the next keywords are required by /usr/sbin/mkinstallp - so provided with defaults
# again - if we want to start working with Relocatable filesets - customization needed here.
	    cat - <<EOF >>$template
  EOUSRFiles
  ROOT Part: N
  ROOTFiles
  EOROOTFiles
  Relocatable: N
EOFileset
EOF
	fi
}

# Now the final fileset added
# RTE - aka run-time-envrionment is the filesset that will always be installed
# 
function add_fileset_rte
{
        # Add the remaining files - opt and usr are the USR part
	typeset expression extension descr du_sizes share fileset ext
	# mk_fileset_al "^/(opt|usr)" "rte"
 	expression="^/(opt|usr)"
	extension="rte"
#	descr=$3
	du_sizes="opt usr"
        # we could make it a coreq - always, but do not know if the .share exists
	# so we do not automate: *coreq $lpp.share
	# instead - it should in the "requisites" file
#	share=$5
	fileset=${lpp}.${extension}
        if [[ $PRODUCT != ${FILESET} ]]; then
		descr="${PRODUCT} ${FILESET} ${today}"
	else
		descr="${PRODUCT} ${today}"
	fi
	cat - <<EOF >>$template
Fileset
  Fileset Name: ${fileset}
  Fileset VRMF: ${vrmf}
  Fileset Description: ${descr}
EOF
	[[ ${AIXV} != "5" ]] && [[ -r ${DOTBUILD}/$lpp.copyright ]] &&\
	    print "Copyright file path: ${DOTBUILD}/$lpp.copyright" >> $template
	usrlpp_files ${extension}

	# BOSBOOT and LAR - No as default
	# LAF* are set in lpp_extra_files
	lpp_extra_files
	cat - <<EOF >>$template
  Bosboot required: N
  License agreement acceptance required: N
  Name of license agreement: $LAR_FILE
  Include license files in this package: $LAF_INCLUDED
  License file path: $LAF_FILE
EOF
	## TODO - add additional requisities via .buildaix/requisites
	ext=${extension}
	> ${DOTBUILD}/requisites.${ext}
	lpp_requisites ${ext}
	add_bos_prereq
#	must be in requisites rather than directly into template file
#	if [[ -s ${TMP}.adt.al ]] && print "*instreq $PROGRAM.adt.$FILESET ${vrmf}" >>${DOTBUILD}/requisites.${ext}
#	[[ ${share} -gt 0 ]] && print "*coreq ${lpp}.share  ${vrmf}" >>${DOTBUILD}/requisites.${ext}
#	[[ ${share} -gt 0 ]] && print "*coreq ${lpp}.share  ${vrmf}" >`tty`

# TODO - set a switch to disable this line
	print "*prereq bos.rte  ${RTEVRML}" >>${DOTBUILD}/requisites.${ext}

	cat - <<EOF >>$template
  Requisites: ${DOTBUILD}/requisites.${ext}
EOF
	do_upsize $du_sizes
	print "  USRFiles" >> $template

# USR part -- i.e. files in /usr and /opt as rte - run-time-environment
	# mk_fileset_al "^/(opt|usr)" "rte"
        mk_fileset_al ${expression} ${extension}
	cat ${TMP}/${extension}.al >>${template}

	print "  EOUSRFiles" >> $template

        
        ## Add the remaining files - etc and var

	## do ROOT part if there are any files in /etc or /var
	## also requires copying the structure of the LPPBASE (aka DESTBUILD)
	## to INSTROOT (that becomes the installp file)
	## todo: verify if directories only is correct!

	cd ${LPPBASE}
	szetc=0
	szvar=0
	[[ -d ./etc ]] && szetc=`du -s ./etc | awk ' { print $1 }'`
	[[ -d ./var ]] && szvar=`du -s ./var | awk ' { print $1 }'`
	if [[ $szetc -gt 0 || $szvar -gt 0 ]]
	then
		# create the directory structure in inst_root
		INSTROOT=${LPPBASE}/usr/lpp/${lpp}/inst_root
		mkdir -p ${INSTROOT}
		if [[ $szetc -gt 0 ]]; then
			find ./etc -type d | backup -if - | (cd ${INSTROOT}; restore -xqf -) >/dev/null
		fi
		if [[ $szvar -gt 0 ]]; then
			find ./var -type d | backup -if - | (cd ${INSTROOT}; restore -xqf -) >/dev/null
		fi

		## update template with ROOT part
		## ROOT part header
		cat - <<EOF >>$template
  ROOT Part: Y
EOF

		# output the root part special files (e.g., .config, .post_i, etc)
		rootlpp_files rte

		# output the root part sizes
		[[ $szvar -gt 0 ]] && do_upsize "var" >> $template
		[[ $szetc -gt 0 ]] && do_upsize "etc" >> $template

		# output the ROOT part files
		cat - <<EOF >>$template
  ROOTFiles
EOF

		cd ${LPPBASE}/..
		[[ $szetc -gt 0 ]] && find ${INST_FILES}/etc \
			| sed -e s#^${INST_FILES}## | sed -e "/^$/d" >>$template
		[[ $szvar -gt 0 ]] && find ${INST_FILES}/var \
			| sed -e s#^${INST_FILES}## | sed -e "/^$/d" >>$template
	else
	## ELSE -- update template with ROOT part is NO
		cat - <<EOF >>$template
  ROOT Part: N
  ROOTFiles
EOF
	fi

## finish fileset definition for "rte"
	cat - <<EOF >>$template
  EOROOTFiles
  Relocatable: N
EOFileset
EOF
}

## init variables, directories ##
## start_template
## filesets
### fileset head
### fileset LPP
### fileset AL
#### ROOT part
#### ROOT Head
#### Root LPP
#### Root AL
## EOFileset

### MAIN ###
cmd=$0
# make sure running bos.adt.insttools is installed and euid is root
lslpp -L bos.adt.insttools >/dev/null
[[ $? -ne 0 ]] \
	&& print "${cmd}:ERROR: bos.adt.insttools is required to proceed" >&2 \
	&& exit 98
[[ `id -u` -ne 0 ]] \
	&& print "${cmd}: mkinstallp must be run with root authority" >&2 \
	&& exit 97
[[ $# == 0 ]] \
	&& print -n 2 $0: Syntax error \
	&& print -n 2 "Syntax: ${cmd} <InstallRootDirectory>" \
	&& exit -1
[[ $# == 2 ]] && VERBOSE=$2

# init global variables
# set BASEDIR LPPBASE
# init mkinstallp variables
# LPPBASE is what we are packaging (aka INSTROOT)
# BASEDIR is build directory of FOSS project
AIXV=$(uname -v)
init_lppbase $1
INSTROOT=${LPPBASE}

# special adjustments aka pre-processing of files
lpp_prepfiles ${LPPBASE}

# create the global applyList - will subtract files from this
# as we process filesets
create_global_al

# start the template with the "one-time" package details
init_template

# Adding Filesets
# add filesets - examine global list for files and add fileset on demand
# add filesets - remove files added as fileset from global list

## Add man pages as seperate fileset
add_fileset "^/(opt|usr)/share/man" "man" "man pages" "*/share/man"

## Add shared pages as seperate fileset
add_fileset "^/(opt|usr)/share" "share" "universal files" "*/share"

## Add adt as seperate fileset
add_fileset "^/(opt|usr)/(include|lib)" "adt" "ADT files" "*/(include|lib)"

# add_fileset "^/(opt|usr)" "rte" "run-time" "usr opt"
# add all remaining files as "rte"
add_fileset_rte 

# additonal processing - used by makebff.pl but not in /usr/sbin/mkinstallp
ls ${BUILDAIX}/*.supersede >/dev/null 2>&1
[[ $? -eq 0 ]] && cp  ${BUILDAIX}/*.supersede ${CONFIGDIR}

## template is complete - call AIX mkinstallp program
 # must actually sit in LPPBASE for ROOT part processing to succeed

cd ${LPPBASE}
echo + mkinstallp -d ${LPPBASE} -T ${template}
#  exec $MAKEBFF_LOCATION/makebff.pl
# TBD: if there are 'special' files, i.e., not handled by the template
## redefine $MAKEBFF_LOCATION to that makebff.pl is a NULL op
## THEN after mkinstallp is called here add the special files into $CONFIGDIR
## and call the 'real' makebff.pl
if [[ $CFG_FILES == "Y" ]]; then
   oPATH=$PATH
   MAKEBFF_LOCATION=${TMP}

   >$MAKEBFF_LOCATION/makebff.pl
   chmod u+x $MAKEBFF_LOCATION/makebff.pl
   cat - <<EOF >$MAKEBFF_LOCATION/makebff.pl
#!/usr/bin/ksh
set -x
find ${DOTBUILD}/user -type f -ls -exec cp -p {} ${CONFIGDIR}  \;
mkdir -p ${CONFIGDIR}/root
find ${DOTBUILD}/root -type f -ls -exec cp -p {} ${CONFIGDIR}/root \;
EOF
    PATH=${TMP}:${PATH}
    MAKEBFF_LOCATION=${TMP} mkinstallp -d ${LPPBASE} -T ${template}
    unset MAKEBFF_LOCATION
    PATH=${oPATH}
fi
if [[ -z ${VERBOSE} ]]; then
	mkinstallp -d ${LPPBASE} -T ${template} 2>&1 >/dev/null
else
	mkinstallp -d ${LPPBASE} -T ${template} 2>&1 >`tty`
fi
status=$?
wait

if [[ ${status} -ne 0 ]]
then
	print "+-------------------------------------------------------------------------+"
	print ${cmd}: mkinstallp returned error status
	print ${cmd}: review contents of ${LPPBASE} and ${template}
	print ${cmd}: previous contents of ${BASEDIR}/installp/ppc is unchanged
	print "+-------------------------------------------------------------------------+"
	exit ${status}
fi

# copy package to ${BASEDIR}
# assume/expect calling script is to delete the LPPBASE

mkdir -p ${BASEDIR}/installp/ppc
rm -f ${BASEDIR}/installp/ppc/.toc

# Leave the cp commands with AIXVER for a later option to specify aixver in the .I filename
#	rm -f ${BASEDIR}/installp/ppc/${lpp}.${vrmf}*.I
	cp ${LPPBASE}/tmp/${lpp}.${vrmf}.bff ${BASEDIR}/installp/ppc/${lpp}.${vrmf}.I
#	cp ${LPPBASE}/tmp/${lpp}.${vrmf}.bff ${BASEDIR}/installp/ppc/${lpp}.${vrmf}.${AIXVER}.I
	chmod a+r ${LPPBASE}/tmp/${lpp}.${vrmf}.bff ${BASEDIR}/installp/ppc/${lpp}.${vrmf}.I

inutoc ${BASEDIR}/installp/ppc

rm -r ${TMP}
