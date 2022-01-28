## Comments transported from the scripts
## AIXINFO
# LPP is short for Licensed PROGRAM PRODUCT
# AIXINFO provides the 4 environment variables needed to label a package:
# PROGRAM.PRODUCT.FILESET.VRMF
# By default, PROGRAM is 'buildaix'. Frequently this is provided via export
# e.g., export PROGRAM=aixtools
# By default, the FILESET is extracted from the current directory
# and PRODUCT is extracted from the sub-directory
# The VRMF is extracted from the current directory
#
# The default PACKAGE filename is:
# ${PROGRAM}.${PRODUCT}.${FILESET}.{VRMF}.I

# When PRODUCT==FILESET the aixinfo looks one directory deeper
# for the the PRODUCT name.
# For example:
# Package directory is: /data/prj/gnu/gcc/gcc-4.7.4
# FILESET and PRODUCT are both 'gcc', so PRODUCT becomes 'gnu'

# When PROGRAM==PRODUCT the package filename becomes:
# ${PROGRAM}.${FILESET}.{VRMF}.I

# VRMF is defined from two strings - $vrm and $f.
# $f is assumed as '0'
# $vrm is extracted from the current directory name: starting with the first
# digit encountered.
# Package directory is: /data/prj/gnu/gcc/gcc-4.7.4
# $vrm = "4.7.4"

# vrm is the first three digits AA.BB.CCCC following the last - (dash)
# fix is 0 by default. if the directory-name is fileset-A.B.C.DDDD then fix=DDDD
# missing numbers are 0, except V - which is 1 by default (so 1.0.0.0 if no numbers)
#
# Besides the filename that gets created, as well as the internal labeling
# these valuse are used to create a package tree is /var/buildaix
# make is called with DESTDIR to be /var/buildaix/${PROGRAM}/${PRODUCT}/${FILESET}/${VRMF}

# the assumption is that projects are organized as:
# /some/where/package/fileset/fileset-v.r.m.f
# or as
# /some/where/package/fileset-v.r.m.f

# If the direct sub-directory is "static" then take product from one-level deeper
# and set PROGRAM to "static"

## MKINSTALLP.KSH
# mkinstallp processing
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

