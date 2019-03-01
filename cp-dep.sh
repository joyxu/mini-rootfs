T=/usr/bin/file
D=/root/test

for library in $(ldd "${T}" | cut -d '>' -f 2 | awk '{print $1}')
do
	[ -f "${library}" ] && cp -farpv --parents "${library}"* "${D}"
done

find ${D} -type l -! -exec test -e {} \; -print | xargs rm
