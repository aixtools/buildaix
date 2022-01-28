
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

