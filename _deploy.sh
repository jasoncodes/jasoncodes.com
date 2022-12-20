#!/bin/bash -e
export PATH="/usr/local/bin:$PATH"
if [ ! -d .git ]
then
	LOG_FILE="`mktemp -t jasoncodes_deploy.log.XXXXXX`"
	trap '{ rm -f "$LOG_FILE"; }' EXIT
	if (
		set -e
		cd ../repo
		git fetch origin
		git reset -q --hard origin/master
		git clean -qxf
		chmod +x _deploy.sh
		./_deploy.sh
	) > "$LOG_FILE" 2>&1
	then
		echo Deploy succeeded.
	else
		echo Deploy failed.
		mail -s "jasoncodes.com deploy error" "`whoami`" < "$LOG_FILE"
	fi
else
	cd ..
	[ -e build.tmp ] && rm -rf build.tmp
	rsync --archive repo/ build.tmp
	(
		set -e
		cd build.tmp
		bundle config set --local path ../vendor/cache
		bundle config set --local deployment true
		bundle install
		bundle exec rake build
	) || exit 1
	[ -e public_html.new ] && rm -rf public_html.new
	[ ! -e public_html ] || rsync --archive public_html/ public_html.new
	rsync -rlpgoDO --checksum --delete build.tmp/_site/ public_html.new/
	rm -rf build.tmp
	[ -e public_html.old ] && rm -rf public_html.old
	[ ! -e public_html ] || mv public_html{,.old}
	mv public_html{.new,}
	wget -q -O /dev/null http://www.google.com/webmasters/sitemaps/ping?sitemap=http://jasoncodes.com/sitemap.xml
fi
