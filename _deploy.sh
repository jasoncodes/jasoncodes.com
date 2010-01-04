#!/bin/bash -e
if [ ! -d .git ]
then
	echo Content-Type: text/plain
	echo
	LOG_FILE="`mktemp -t jasoncodes_deploy.log.XXXXXX`"
	trap '{ rm -f "$LOG_FILE"; }' EXIT
	(
		set -e
		cd ../repo
		git fetch origin
		git reset -q --hard origin/master
		git clean -qxf
		chmod +x _deploy.sh
		./_deploy.sh
	) > "$LOG_FILE" 2>&1
	if [ "$?" -eq 0 ]
	then
		echo Deploy succeeded.
	else
		echo Deploy failed.
		mail -s "jasoncodes.com deploy error" "`whoami`" < "$LOG_FILE"
	fi
else
	cd ..
	[ -e build.tmp ] && rm -rf build.tmp
	(cd repo && git checkout-index --all --prefix=../build.tmp/) || exit 1
	(cd build.tmp && rake build) || exit 1
	[ -e public_html.new ] && rm -rf public_html.new
	[ ! -e public_html ] || rsync --archive public_html/ public_html.new
	rsync -rlpgoDO --checksum --delete build.tmp/_site/ public_html.new/
	rm -rf build.tmp
	[ -e public_html.old ] && rm -rf public_html.old
	[ ! -e public_html ] || mv public_html{,.old}
	mv public_html{.new,}
fi
