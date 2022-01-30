#!/usr/bin/ksh -e
#!/usr/bin/ksh -e
# Merge the X32 mnd X64 libraries into the libXX archive

argument=$1
library=${argument##*/}
dirpath=${argument#*/}
dirpath=${dirpath%/*}

lib32=X32/${dirpath}/${library}
lib64=X64/${dirpath}/${library}
libXX=Xany/${dirpath}/${library}

# ls -l ${lib32} ${lib64} ${libXX} 

	print ${libXX} starting
        [[ -L ${libXX} ]] && print skipping symbolic link $i && exit 0

	rm -f ${libXX}
	cp -p ${lib64} ${libXX}

	mkdir -p .tmp.$$
	cd .tmp.$$
	ar -X32 x ../${lib32}
	ar -X32 t ../${lib32} | xargs ar -X32 r ../${libXX}

	cd ..
	rm -rf .tmp.$$

# print archive: ${libXX} contents
# ar -Xany -tv ${libXX} | sort -k 8
# ls -l ${lib32} ${lib64} ${libXX} 
# print
	print ${libXX} finished
