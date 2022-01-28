#!/usr/bin/ksh -e
# Copy the X32 members to the Xany archive
# script to combine archive members from X32/opt/lib and X64/opt/lib to Xany/opt/lib
# does not do/work with sub-directories if X??/opt/lib (yet)

lib=$(basename $1)
lib32=X32/opt/lib/$lib
lib64=Xany/opt/lib/$lib

print $lib64 starting
    [[ -L $lib64 ]] && print skipping symbolic link $i && exit 0

rm -f $lib64
cp -p X64/opt/lib/$lib $lib64

mkdir -p .tmp.$$
cd .tmp.$$
ar -X32 x ../$lib32
ar -X32 t ../$lib32 | xargs ar -X32 r ../$lib64

cd ..
rm -rf .tmp.$$

# print archive: $lib64 contents
# ar -Xany -tv $lib64 | sort -k 8
print $lib64 finished
