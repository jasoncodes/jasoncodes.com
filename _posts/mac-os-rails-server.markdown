---
layout: post
title: Hosting Rails apps on a Mac OS X server
short: hostmac
date: 2011-02-07
updated: 2011-03-26
---

There are many guides for setting up Rails development environments on various platforms including Mac OS and Ubuntu. I thought I'd mix it up a little with my complete guide on setting up a production Mac OS server.

**Update 2011-02-12**: Added a note to the [backups](#backups) section on excluding large changing files (such as databases) from Time Machine backups.

**Update 2011-03-26** All launchd configuration files for services should be placed in `LaunchDaemons` not `LaunchAgents` to run at startup as the correct user account. `LaunchAgents` are for interactive processes ran under as the logged in console user.

# Contents

* [Xcode](#xcode)
* [Homebrew](#homebrew)
* [Sysadmin tweaks](#admin)
* [Ruby 1.9.2 via system-wide RVM](#ruby)
* [Apache & Passenger](#apache)
* [User accounts](#users)
* [Email](#email)
* [PostgreSQL](#postgresql)
* [Memcached](#memcached)
* [ImageMagick](#imagemagick)
* [Tomcat](#tomcat)
* [Git Hosting](#git)
* [SSH on an alternate port](#ssh-alt)
* [Monit](#monit)
* [Backups](#backups)
* [Applications](#apps)

# Xcode [xcode]

Download and install [Xcode](http://developer.apple.com/technologies/xcode.html) if you haven't already. It provides useful tools like a C compiler. Pretty much nothing is going to work without one.


# Homebrew [homebrew]

[Homebrew](http://mxcl.github.com/homebrew/) is an awesome package manager for Mac OS. It's superior to [MacPorts](http://www.macports.org/) in many ways. If you're setting up a new machine, there's no decision to be made. If you're already running MacPorts it's still seriously worth switching over.

You can follow the [Homebrew installation instructions](https://github.com/mxcl/homebrew/wiki/installation) on the Homebrew wiki or run the steps below to use my formulas:

{% highlight bash %}
ruby -e "$(curl -fsSL https://gist.github.com/raw/323731/install_homebrew.rb)"
brew install git
git clone http://github.com/jasoncodes/homebrew.git /tmp/homebrew # substitute your preferred fork
mv /tmp/homebrew/.git /usr/local/
rm -rf /tmp/homebrew
cd /usr/local/
git remote add mxcl http://github.com/mxcl/homebrew.git
git fetch --all
{% endhighlight %}


# Sysadmin tweaks [admin]

## GNU command-line utilities [gnu]

Installing a few GNU utilities makes Mac OS's BSD userland feel more like home. You can skip this step if you're happy with the BSD variants and your apps don't need GNU flavour.

{% highlight bash %}
brew install coreutils gnu-sed gawk findutils --default-names
{% endhighlight %}

Note: Installing these tools with `--default-names` will make the GNU variants the default and could possibly cause issues with any scripts that expect BSD versions. The GNU versions generally accept all the options as the BSD versions but there are a few differences. For example: BSD `sed` uses `-E` for extended mode and GNU `sed` uses `-r` and `--regexp-extended`. For compatibility with the BSD version of `sed` I use `/usr/bin/sed` in this guide.

## dot files [dotfiles]

I have customized my environment quite a bit and it can be frustrating to use a machine without my settings. As such, I like to install on every machine I use. Everything in this post should work on a bare config (and hopefully under your config as well). Here's what I run to setup my shell config:

{% highlight bash %}
curl -sL http://github.com/jasoncodes/dotfiles/raw/master/install.sh | bash
exec bash -i # reload the shell
{% endhighlight %}

## htop [htop]

[`htop`](http://htop.sourceforge.net/) is a `top` alternative which makes interactive use much easier. It primarily targets Linux but the basic functions work fine on Mac OS. It's far nicer to use than the version of `top` which comes with Mac OS.

{% highlight bash %}
brew install htop
{% endhighlight %}

You'll need to `sudo htop` when running htop in order to see all process information. I also like to enable the `Highlight program "basename"` setting.


# Ruby 1.9.2 via system-wide RVM [ruby]

If you haven't already, have a quick read of [Installing RVM System Wide](http://rvm.beginrescueend.com/deployment/system-wide/) in the RVM documentation to see differences between a normal and system-wide RVM install.

## Install RVM [rvm]

{% highlight bash %}
sudo bash < <(curl -s https://rvm.beginrescueend.com/install/rvm)
echo -e "[[ -s '/usr/local/rvm/scripts/rvm' ]] && source '/usr/local/rvm/scripts/rvm'\n" | sudo bash -c 'cat - /etc/bashrc > /etc/bashrc.new && mv /etc/bashrc{.new,}' # add RVM to global shell config
source '/usr/local/rvm/scripts/rvm' # load RVM in current session
{% endhighlight %}

We prepend the RVM loader to `/etc/bashrc` so it runs on non-interactive shells such as cron. This in combination with [`/bin/bash -l -c`](http://blog.scoutapp.com/articles/2010/09/07/rvm-and-cron-in-production) (which is automatically provided by the [whenever](https://github.com/javan/whenever) gem), we can have the RVM provided Ruby 1.9.2 available in cron jobs.

## Install Ruby 1.9.2 and set it as default [rvm-ruby]

{% highlight bash %}
sudo rvm package install readline
sudo rvm install 1.9.2 --with-readline-dir=$rvm_path/usr
sudo rvm --default 1.9.2
rvm default
{% endhighlight %}

**Update**: These instructions originally installed `libyaml` for the Psych YAML parser on Ruby 1.9.2.
Unfortunately Ruby 1.9.2 up to and including p180 has an issue with Psych where by it fails with merge keys.
This can cause problems with certain versions of Bundler and RubyGems, as well as DRY database.yml files.
The issue is [fixed in Ruby HEAD](http://redmine.ruby-lang.org/issues/show/4300)
and there's a now somewhat stale ticket open to [backport to 1.9.2](http://redmine.ruby-lang.org/issues/show/4357).
Hopefully we see a fix in the next Ruby 1.9.2 patch release.

## Fix Homebrew permissions broken by installing RVM system-wide [rvm-homebrew-permissions]

After installing RVM system-wide you may find `/usr/local/lib` and `/usr/local/bin` to be locked down. We can liberate them again without reinstalling Homebrew by coping the owner and permissions from another directory (such as `/usr/local/share/man`) which is unaffected by the installation of RVM.

{% highlight bash %}
sudo chmod -R --reference=/usr/local/lib /usr/local/bin /usr/local/share/man
sudo chown -R --reference=/usr/local/lib /usr/local/bin /usr/local/share/man
{% endhighlight %}

## Install Bundler [bundler]

We'll be using Bundler's deployment mode via Capistrano to install and manage gems. This keeps our system gems clean and isolates apps from each other.

{% highlight bash %}
sudo gem install bundler
{% endhighlight %}


# Apache & Passenger [apache]

Apache 2 comes standard with Mac OS 10.6. Sprinkle [Phusion Passenger](http://www.modrails.com/) on top and we have an app server for Rack apps (including Rails).

{% highlight bash %}
sudo gem install passenger
rvmsudo passenger-install-apache2-module
{% endhighlight %}

Copy the 3 configuration lines emitted after installation into `/etc/apache2/other/passenger.conf`:

{% highlight apache %}
LoadModule passenger_module /usr/local/rvm/gems/ruby-1.9.2-p136/gems/passenger-3.0.2/ext/apache2/mod_passenger.so
PassengerRoot /usr/local/rvm/gems/ruby-1.9.2-p136/gems/passenger-3.0.2
PassengerRuby /usr/local/rvm/wrappers/ruby-1.9.2-p136/ruby
{% endhighlight %}

There are a number of configuration options you can set in `passenger.conf` to control how it manages worker instances. You can read about these in the [Passenger users guide](http://www.modrails.com/documentation/Users%20guide%20Apache.html). Here's the settings I'm using:

{% highlight apache %}
RailsSpawnMethod smart-lv2
RailsFrameworkSpawnerIdleTime 0
RailsAppSpawnerIdleTime 0
PassengerUseGlobalQueue on
PassengerFriendlyErrorPages off

# recycle instances every so often to keep any leaks under control
PassengerMaxRequests 1000

# default 6
PassengerMaxPoolSize 16

# default 0
PassengerMaxInstancesPerApp 5

# keep at least one instance around per app, let the others time out after 2 minutes
PassengerMinInstances 1
PassengerPoolIdleTime 120
{% endhighlight %}

For the configuration changes to take affect you need to restart Apache by running the following:

{% highlight bash %}
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist
sudo launchctl load -w /System/Library/LaunchDaemons/org.apache.httpd.plist
{% endhighlight %}

Once restarted you should see Passenger in the server signature:

{% highlight bash %}
$ curl -sI localhost | grep ^Server
Server: Apache/2.2.15 (Unix) mod_ssl/2.2.15 OpenSSL/0.9.8l DAV/2 Phusion_Passenger/3.0.2
{% endhighlight %}

## HTTP Compression [compression]

`mod_deflate` is loaded by default but it's not configured to compress any responses automatically. Save the following as `/etc/apache2/other/deflate.conf` to enable HTTP compression for HTML, CSS, Javascript and fonts:

{% highlight apache %}
AddOutputFilterByType DEFLATE text/html text/plain text/xml font/ttf font/otf application/vnd.ms-fontobject text/css application/javascript application/atom+xml
{% endhighlight %}

## Virtual Hosts [apache-vhosts]

It's useful to have a default virtual host to catch any hits that goto any undefined hostnames or direct IP requests.
Here's a basic vhost which will act as the default. The key thing to note here is the zeros in the filename which causes it to sort before the other vhost files and Apache's `Include` to load it first.

`/etc/apache2/other/vhosts-000default.conf`:

{% highlight apache %}
NameVirtualHost *:80
<VirtualHost *:80>
  ServerName _default_
  <Directory /Library/WebServer/Documents>
    AllowOverride All
  </Directory>
</VirtualHost>
{% endhighlight %}

Let's use something a bit better than "It works!" as our default page.

`/Library/WebServer/Documents/index.html`:

{% highlight html %}
<!DOCTYPE html>
<html>
  <head>
    <title></title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  </head>
  <body>
    <p>Move along, nothing to see here&hellip;</p>
  </body>
</html>
{% endhighlight %}

We don't want it to be cacheable just in case we screw up and end up serving it instead of a vhost.

`/Library/WebServer/Documents/.htaccess`:

{% highlight apache %}
# Expire default page immediately
ExpiresActive On
ExpiresByType text/html "access"
{% endhighlight %}

And finally here's my template for all vhosts which we'll be using a bit later:

`/etc/apache2/other/vhosts-example.conf.template`:

{% highlight apache %}
<VirtualHost *:80>

  ServerName example.com
  ServerAlias www.example.com

  # no-www
  RewriteEngine On
  RewriteCond %{HTTP_HOST} ^www\.(.*)$ [NC]
  RewriteRule ^(.*)$ http://%1$1 [R=301,L]

  ServerAdmin webmaster@example.com
  DocumentRoot /Users/example/apps/example/production/current/public/

  LogLevel warn
  CustomLog /var/log/apache2/example-production-access.log "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\" \"%{Host}i\" %D"
  ErrorLog /var/log/apache2/example-production-error.log

  <Directory />
    AllowOverride FileInfo Indexes Options
    Options -Indexes FollowSymLinks -MultiViews
    Order allow,deny
    Allow from all
  </Directory>

</VirtualHost>
{% endhighlight %}

To check the configuration syntax and then reload Apache so new vhosts are available, run the following:

{% highlight bash %}
sudo apachectl configtest && sudo apachectl graceful
{% endhighlight %}

## `apache2ctl` errors [apache2ctl]

If `apachectl` outputs an error like `/usr/sbin/apachectl: line 82: ulimit: open files: cannot modify limit: Invalid argument`, you've ran into a Mac OS 10.6.6 regression. You can patch `apachectl` by running the following:

{% highlight bash %}
sudo /usr/bin/sed -E -i bak 's/^(ULIMIT_MAX_FILES=".*)`ulimit -H -n`(")$/\11024\2/' /usr/sbin/apachectl
{% endhighlight %}

## Passenger Preference Pane [passenger-preference-pane]

A quick note on [Passenger Preference Pane](http://www.fngtps.com/passenger-preference-pane): I don't recommend you install it.
It can be handy in development environments with Passenger for quickly spinning up a new vhost for an app. It does not however allow you to customise vhost settings like logging nor setup a default vhost.

It's a much better idea to create a template and then script the deployment of new applications in production environments. There's more to deploying an app than just creating a new vhost. We also need to create user accounts, databases, configure logging, etc.

## Log rotation [apache-logs]

Mac OS uses `newsyslog` to rotate the main log files such as `system.log` and `mail.log`. It does not however automatically rotate anything in `/var/log/apache2`.
We could point `newsyslog` at each log file we want to rotate but `logrotate` lets us use wildcards.

{% highlight bash %}
brew install logrotate
sudo mkdir -p /etc/logrotate.d
sudo bash -c 'cat > /etc/logrotate.conf' <<EOF
compresscmd $(which gzip)
tabooext + template
include /etc/logrotate.d
EOF
{% endhighlight %}

Set your Apache log rotate settings. I prefer to rotate my logs weekly and keep 520 rotations (10 years). Disk space is cheap and old logs might be useful. Save the following config as `/etc/logrotate.d/apache.conf`:

{% highlight text %}
/var/log/apache2/access_log /var/log/apache2/error_log /var/log/apache2/*.log {
  weekly
  missingok
  rotate 520
  compress
  delaycompress
  notifempty
  create 640 root wheel
  sharedscripts
  postrotate
    apachectl graceful
  endscript
}
{% endhighlight %}

Since we're going to be reloading Apache after rotating the logs, we can use this opportunity to rotate `production.log` from our Rails apps. These logs are larger so I only keep 10 rotations. Save the following template as `/etc/logrotate.d/vhosts-example.conf.template`:

{% highlight text %}
/Users/example/apps/example/production/shared/log/production.log {
  weekly
  missingok
  rotate 10
  compress
  delaycompress
  notifempty
  create 640 example staff
  sharedscripts
}
{% endhighlight %}

Setup `logrotate` to run automatically via `launchd`. Debian runs `logrotate` daily at 06:25 which sounds fine by me. See [man 5 launchd.plist](http://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man5/launchd.plist.5.html) for details on the `StartCalendarInterval` option. Save the following as `/Library/LaunchDaemons/logrotate.plist`:

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>logrotate</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/sbin/logrotate</string>
    <string>/etc/logrotate.conf</string>
  </array>
  <key>Disabled</key>
  <false/>
  <key>RunAtLoad</key>
  <false/>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>6</integer>
    <key>Minute</key>
    <integer>25</integer>
  </dict>
</dict>
</plist>
{% endhighlight %}

And finally run the following to force an initial test rotation and then activate the `launchd` schedule:

{% highlight bash %}
sudo /usr/local/sbin/logrotate -f /etc/logrotate.conf
sudo launchctl load -w /Library/LaunchDaemons/logrotate.plist
{% endhighlight %}


# User accounts [users]

We want to isolate our services (PostgreSQL, Memcached, etc) and applications in their own user accounts.
Unfortunately Mac OS doesn't provide a nice and simple `adduser` like command but we can make our own. Save the following as `/usr/local/bin/adduser` and run `chmod +x /usr/local/bin/adduser` to make it executable:

{% highlight bash %}
#!/bin/bash -e
NEW_USERNAME="$1"
if [ -z "$NEW_USERNAME" ]
then
  echo "Usage: $(basename "$0") [username]" >&2
  exit 1
fi
if id "$NEW_USERNAME" 2> /dev/null
then
  echo "$(basename "$0"): User \"$NEW_USERNAME\" already exists." >&2
  exit 1
fi

NEW_UID=$(( $(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1) + 1 ))

if ! [ $NEW_UID -gt 500 ]
then
  echo "$(basename "$0"): Could not determine new UID." >&2
  exit 1
fi

dscl . create "/Users/$NEW_USERNAME"
dscl . create "/Users/$NEW_USERNAME" UniqueID $NEW_UID
dscl . create "/Users/$NEW_USERNAME" PrimaryGroupID 20
dscl . delete "/Users/$NEW_USERNAME" AuthenticationAuthority
dscl . create "/Users/$NEW_USERNAME" Password '*'
dscl . create "/Users/$NEW_USERNAME" UserShell /bin/bash
dscl . create "/Users/$NEW_USERNAME" NFSHomeDirectory "/Users/$NEW_USERNAME"
createhomedir -c -u "$NEW_USERNAME"
{% endhighlight %}

Now we can simply run `sudo adduser foo` to create a new account which will not show on the login screen.

Removing a user account later is much easier than creating one. Just run the following:

{% highlight bash %}
sudo dscl . delete /Users/foo
sudo rm -rf /Users/foo
{% endhighlight %}


# Email [email]

Sometimes cron jobs fail. Wouldn't it be nice to hear about it? It's fairly easy to setup `postfix` to send mail via an external server. You could use [Gmail](http://mail.google.com/support/bin/answer.py?hl=en&answer=13287), [SendGrid](http://sendgrid.com/) or even your own mail server.

Configure `postfix` to forward mail to smtp.example.com with SSL and authentication. Replace both instances of `smtp.example.com` with your SMTP server's hostname and `username:password` with the username and password for your SMTP account.

{% highlight bash %}
sudo bash -c 'umask 0077 > /dev/null && echo "smtp.example.com username:password" >> /etc/postfix/smtp_auth'
sudo postmap hash:/etc/postfix/smtp_auth
sudo postconf -e relayhost=smtp.example.com:submission smtp_use_tls=yes smtp_sasl_auth_enable=yes smtp_sasl_password_maps=hash:/etc/postfix/smtp_auth tls_random_source=dev:/dev/urandom smtp_sasl_security_options=noanonymous
{% endhighlight %}

Forward root's mail to an external account. Replace `me@example.com` with your email address.

{% highlight bash %}
sudo cp -ai /etc/postfix/aliases{,.bak} # backup the original aliases file
sudo /usr/bin/sed -i '' 's/^#root.*/root: me@example.com/' /etc/postfix/aliases
grep ^root /etc/aliases # check the replacement worked
sudo postalias /etc/aliases
{% endhighlight %}

Set `postfix` to listen on `localhost` only. There's no need to give spam zombie's the time of day.

{% highlight bash %}
sudo postconf -e inet_interfaces=localhost
{% endhighlight %}

By default `postfix` will only start when there's mail in the local queue (typically from calls to `sendmail`). We'll use our own `launchd` config which will run `postfix` all the time. Save the following as `/Library/LaunchDaemons/org.postfix.master.plist`:

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>org.postfix.master</string>
  <key>Program</key>
  <string>/usr/libexec/postfix/master</string>
  <key>ProgramArguments</key>
  <array>
    <string>master</string>
  </array>
  <key>AbandonProcessGroup</key>
  <true/>
  <key>RunAtLoad</key>
  <true />
  <key>KeepAlive</key>
  <true />
</dict>
</plist>
{% endhighlight %}

Start the `postfix` daemon and check port 25 is now open:

{% highlight bash %}
nc -4zv localhost 25 # should error
sudo launchctl unload -w /System/Library/LaunchDaemons/org.postfix.master.plist # stop built in on demand daemon
sudo launchctl load -w /Library/LaunchDaemons/org.postfix.master.plist # load our always running daemon
nc -4zv localhost 25 # should succeed
{% endhighlight %}

Forward your email to root (which will forward to your designated email address):

{% highlight bash %}
echo root > ~/.forward
{% endhighlight %}

Send yourself a test email:

{% highlight bash %}
date | mail -s "Test from $(hostname -s)" $USER
{% endhighlight %}


# PostgreSQL [postgresql]

{% highlight bash %}
brew install postgresql
{% endhighlight %}

The instructions included in the caveats blurb from Homebrew (which after you run `brew install postgresql`) are great for setting up a single user development install. However, we want to run a system-wide instance to be used by all our applications. Run the following instead to setup PostgreSQL with ident authentication under the `postgres` account.

{% highlight bash %}
# create user account
sudo adduser postgres
# initialize the database cluster
sudo -u postgres initdb -A ident /usr/local/var/postgres
# set PostgreSQL to run at startup
sudo cp /usr/local/Cellar/postgresql/9.0.1/org.postgresql.postgres.plist /Library/LaunchDaemons/
sudo defaults write /Library/LaunchDaemons/org.postgresql.postgres UserName postgres
sudo plutil -convert xml1 /Library/LaunchDaemons/org.postgresql.postgres.plist
sudo chmod 644 /Library/LaunchDaemons/org.postgresql.postgres.plist
# start the server
sudo launchctl load -w /Library/LaunchDaemons/org.postgresql.postgres.plist
{% endhighlight %}

Add yourself as a superuser on the cluster so you can manage it without `sudo -u postgres`:

{% highlight bash %}
sudo -u postgres createuser -s $USER
createdb
{% endhighlight %}

The default PostgreSQL memory settings are very conservative. On a production machine you'll want to adjust these to suit your workload. Run `sudo cp -ai /usr/local/var/postgres/postgresql.conf{,.org}` before editing the config so you have a pristine copy of the config file to reference later.

Below are my current settings for my server which will give you an idea of what settings to play with. See [Resource Consumption](http://www.postgresql.org/docs/9.0/static/runtime-config-resource.html) in the PostgreSQL docs for what each setting means. I recommend you start small and nothing beats trial, error and lots of testing. Don't forget to benchmark with production queries against production data.

{% highlight bash %}
shared_buffers = 256MB
work_mem = 64MB
maintenance_work_mem = 128MB
effective_cache_size = 512MB
max_connections = 50
{% endhighlight %}

If you're adjusting the `shared_buffers` setting you will probably run into the following error (in `/var/log/messages`):

{% highlight text %}
FATAL: could not create shared memory segment: Invalid argument
DETAIL: Failed system call was shmget(key=5432001, size=276275200, 03600).
HINT: This error usually means that PostgreSQL's request for a shared memory segment exceeded your kernel's SHMMAX parameter.  You can either reduce the request size or reconfigure the kernel with larger SHMMAX.  To reduce the request size (currently 276275200 bytes), reduce PostgreSQL's shared_buffers parameter (currently 32768) and/or its max_connections parameter (currently 24).
If the request size is already small, it's possible that it is less than your kernel's SHMMIN parameter, in which case raising the request size or reconfiguring SHMMIN is called for.
The PostgreSQL documentation contains more information about shared memory configuration.
{% endhighlight %}

The fix is easy. First make sure the quoted request size sounds sane (263 MB in the above error) and then update `SHMMAX` to be at least as large. I generally to round up to the next power of 2. `SHMALL` should generally be set to `ceil(SHMMAX/PAGE_SIZE)` where `PAGE_SIZE` is 4096 bytes. I'm setting `SHMMAX` to 512 MB:

{% highlight bash %}
sudo sysctl -w kern.sysv.shmmax=$((1048576 * 512))
sudo sysctl -w kern.sysv.shmall=$((1048576 / 4096 * 512))
sysctl -a | egrep '^kern.sysv.shm(max|all)' | /usr/bin/sed 's/: /=/' | sudo tee -a /etc/sysctl.conf
{% endhighlight %}

To restart the server run the following:

{% highlight bash %}
sudo launchctl unload -w /Library/LaunchDaemons/org.postgresql.postgres.plist
sudo launchctl load -w /Library/LaunchDaemons/org.postgresql.postgres.plist
{% endhighlight %}

Finally type `psql` and you should drop straight into a PostgreSQL prompt.

## Granting permissions [postgresql-permissions]

Sometimes you may want to give full privileges on a database to a non-superuser account which is not the database owner.
For example: you may want to share a database between two apps or let developers play around with data on a staging instance.

To grant full access to a database to a non-superuser you can use the following in a superuser `psql` prompt:

{% highlight bash %}
GRANT ALL ON DATABASE $database TO $user;
\c $database
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO $user;
{% endhighlight %}


# Memcached [memcached]

{% highlight bash %}
# install memcached
brew install memcached
# configure to run at startup
sudo adduser memcache
sudo cp /usr/local/Cellar/memcached/1.4.5/com.danga.memcached.plist /Library/LaunchDaemons/
sudo defaults write /Library/LaunchDaemons/com.danga.memcached UserName memcache
sudo plutil -convert xml1 /Library/LaunchDaemons/com.danga.memcached.plist
sudo chmod 644 /Library/LaunchDaemons/com.danga.memcached.plist
# start the service
sudo launchctl load -w /Library/LaunchDaemons/com.danga.memcached.plist
{% endhighlight %}

Memcached defaults to a maximum cache size of 64 MB. You can increase this if needed with by adding `-m`, `128` to `ProgramArguments` in the launchd plist and restarting the service.

Running `echo stats | nc localhost 11211` should give you memcached stats.

## Sharing the cache with multiple applications & security issues [memcached-security]

If you're configuring multiple applications to use it, make sure you namespace your keys with something like:

{% highlight ruby %}
config.cache_store = :mem_cache_store, { :namespace => Rails.application.config.database_configuration[Rails.env]['database'] }
{% endhighlight %}

If you have untrusted users/applications, you'll probably want to setup multiple instances with [SASL authentication](http://code.google.com/p/memcached/wiki/SASLHowto).


# ImageMagick [imagemagick]

If your applications resize images with RMagick, you're going to need the ImageMagick libraries. Installing with `--disable-openmp` fixes some random crashing issues I was having.

{% highlight bash %}
brew install imagemagick --disable-openmp
{% endhighlight %}


# Tomcat [tomcat]

To run [Solr](http://lucene.apache.org/solr/) one needs a servlet container. [Tomcat](http://tomcat.apache.org/) is a safe bet here. I recommend the excellent [Sunspot](http://outoftime.github.com/sunspot/) library for using Solr in Rails.

## Installing [tomcat-installing]

Install Tomcat via Homebrew and then unlink it. Tomcat comes with a number of scripts which have generic names (`startup.sh`, `version.sh`, etc). We don't want those in our `PATH`.

{% highlight bash %}
brew install tomcat
brew unlink tomcat
{% endhighlight %}

Setup Tomcat to run in its own path (`/usr/local/tomcat`) under its own username (`tomcat`):

{% highlight bash %}
sudo adduser tomcat
sudo mkdir /usr/local/tomcat
sudo chown tomcat /usr/local/tomcat
sudo -u tomcat ln -s $(brew --prefix tomcat)/libexec /usr/local/tomcat/
sudo -u tomcat ln -s libexec/{bin,lib} /usr/local/tomcat
sudo -u tomcat mkdir /usr/local/tomcat/{logs,temp,webapps,work}
sudo rsync --archive --no-perms --chmod='ugo=rwX' /usr/local/tomcat/{libexec/conf/,conf}
sudo find /usr/local/tomcat/conf -exec chown tomcat:staff {} \;
sudo -u tomcat bash -c 'echo "org.apache.solr.level = WARNING" >> /usr/local/tomcat/conf/logging.properties'
{% endhighlight %}

## Configure connectors [tomcat-connectors]

I recommend editing `/usr/local/tomcat/conf/server.xml` and replacing all `<Connector />` entries with a single [HTTP connector](http://tomcat.apache.org/tomcat-7.0-doc/config/http.html) for `localhost:8080`:

{% highlight xml %}
<Connector address="127.0.0.1" port="8080" protocol="HTTP/1.1" connectionTimeout="20000" />
{% endhighlight %}

## Run at startup [tomcat-startup]

Save the following as `/Library/LaunchDaemons/org.apache.tomcat.plist` to have launchd start Tomcat automatically:

Note: Adjust `-Xmx2048M` to control how much memory Tomcat can use.

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>org.apache.tomcat</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/tomcat/bin/catalina.sh</string>
    <string>run</string>
  </array>
  <key>UserName</key>
  <string>tomcat</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CATALINA_HOME</key>
    <string>/usr/local/tomcat</string>
    <key>JAVA_OPTS</key>
    <string>-Djava.awt.headless=true -Xmx2048M</string>
  </dict>
  <key>Disabled</key>
  <false/>
  <key>RunAtLoad</key>
  <true/>
  <key>HopefullyExitsFirst</key>
  <true/>
  <key>ExitTimeOut</key>
  <integer>60</integer>
</dict>
</plist>
{% endhighlight %}

Finally, start Tomcat with the following:

{% highlight bash %}
sudo launchctl load -w /Library/LaunchDaemons/org.apache.tomcat.plist
{% endhighlight %}

To upgrade Tomcat to a newer version in the future, see my [Upgrading Tomcat with Homebrew](/posts/homebrew-tomcat-upgrade) post.


# Git Hosting [git]

Run the following as your admin user on the server to install [gitolite](http://github.com/sitaramc/gitolite):

{% highlight bash %}
# create git user account
sudo adduser git
# copy our admin public key over to the git account
sudo cp ~/.ssh/id_rsa.pub ~git/$USER.pub
sudo chown git ~git/$USER.pub
# switch to git user and configure shell
sudo -u git -i
curl -sL http://github.com/jasoncodes/dotfiles/raw/master/install.sh | bash
exec bash -i # reload the shell
# clone gitolite source code
git clone git://github.com/sitaramc/gitolite gitolite-source
# install gitolite
cd gitolite-source
mkdir -p ~/bin ~/share/gitolite/conf ~/share/gitolite/hooks
src/gl-system-install ~/bin ~/share/gitolite/conf ~/share/gitolite/hooks
cd
# configure gitolite with ourselves as the admin
gl-setup $SUDO_USER.pub
# cleanup
rm $SUDO_USER.pub
exit
{% endhighlight %}

From your workstation you can then clone the config repo by running:

{% highlight bash %}
git clone git@$SERVER:gitolite-admin.git $SERVER-gitolite-admin
{% endhighlight %}

The [documentation](http://sitaramc.github.com/gitolite/doc/) should contain everything you need. If you're new you'll want to read [gitolite.conf](http://sitaramc.github.com/gitolite/doc/gitolite.conf.html) for permission config and [migrate](http://sitaramc.github.com/gitolite/doc/migrate.html) if you're moving from Gitosis.


# SSH on an alternate port [ssh-alt]

I want SSH to be available on both IPv4 and IPv6 on an alternate secondary port. I could use `ipfw add 01000 fwd 127.0.0.1,22 tcp from any to me 4242` for IPv4 but `ip6fw` doesn't support forwarding. We can however just have `launchd` listen for SSH connections on an alternate port by running the following:

Note: Replace 4242 with your desired alternate port number.

{% highlight bash %}
sudo cp /System/Library/LaunchDaemons/ssh.plist /Library/LaunchDaemons/ssh-alt.plist
sudo defaults write /Library/LaunchDaemons/ssh-alt Label com.openssh.sshd-alt
sudo defaults write /Library/LaunchDaemons/ssh-alt Sockets '{ Listeners = { SockServiceName = 4242; }; }'
sudo plutil -convert xml1 /Library/LaunchDaemons/ssh-alt.plist
sudo chmod 644 /Library/LaunchDaemons/ssh-alt.plist
sudo launchctl load -w /Library/LaunchDaemons/ssh-alt.plist
{% endhighlight %}

Now with this port opened on my firewall I can use the following in my `~/.ssh/config` to easily connect to my server with `ssh server`:

{% highlight apache %}
Host server
  HostName server.example.com
  Port 4242
{% endhighlight %}


# Monit [monit]

[Monit](http://mmonit.com/monit/) is a great tool that lets you monitor processes and make sure they're still serving requests. `launchd` handles restarting of failed services for us automatically but processes could still hang. This is where `monit` comes into the picture.

Check out the [documentation](http://mmonit.com/monit/documentation/monit.html) for what can be monitored. Resources you can monitor include load average, system memory usage, disk space, process memory usage and connectivity.

First thing is to install `monit`. You'll need at least 5.2.3 as earlier versions are prone to crash on Mac OS. If you're using [my Homebrew fork](#homebrew), you're all good to go.

{% highlight bash %}
sudo brew install monit
{% endhighlight %}

Create `/etc/monitrc`:

{% highlight text %}
set daemon 30 with start delay 60
set mail-format { from: root@server.example.com }
set alert root@server.example.com
set mailserver localhost
set httpd port 2812 allow localhost

check process apache2 with pidfile /var/run/httpd.pid
  if failed URL http://localhost:80/ with timeout 5 seconds then alert

check host postgresql with address 127.0.0.1
  if failed port 5432 with timeout 5 seconds then alert

check host tomcat with address 127.0.0.1
  if failed port 8080
    send "HEAD / HTTP/1.0\r\n\r\n"
    expect "HTTP/1.1"
    with timeout 5 seconds
    then alert

check host memcached with address 127.0.0.1
  if failed port 11211
    send "stats\n"
    expect "STAT pid"
    with timeout 5 seconds
    then alert
{% endhighlight %}

Save the following as `/Library/LaunchDaemons/monit.plist`:

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>UserName</key>
  <string>root</string>
  <key>Label</key>
  <string>monit</string>
  <key>OnDemand</key>
  <false/>
  <key>RunAtLoad</key>
  <true/>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/monit</string>
    <string>-c</string>
    <string>/etc/monitrc</string>
    <string>-I</string>
    <string>-l</string>
    <string>/var/log/monit.log</string>
  </array>
</dict>
</plist>
{% endhighlight %}

Secure the config file, check the syntax, and then start `monit`:

{% highlight bash %}
sudo chmod 600 /etc/monitrc
sudo monit -t /etc/monitrc
sudo launchctl load -w /Library/LaunchDaemons/monit.plist
{% endhighlight %}

If you `kill -STOP` or otherwise break a service and you should get an email letting you know. You can view the current status with `sudo monit status`.

## Restarting failed services

A great feature of Monit is that it can run tasks for you when something bad happens. In the case of Tomcat, I have created a script which kills Tomcat and then relaunches it. See my [Restarting Tomcat automatically on Mac OS with Monit](/posts/homebrew-tomcat-monit) post for details.


# Backups [backups]

My current local backup solution consists of both Time Machine backups to a Time Capsule and a weekly startup disk image with [Carbon Copy Cloner](http://www.bombich.com/).
A problem with both of these solutions though is that they can't quiesce database writes to allow atomic snapshots. Hopefully Apple's working on their own ZFS/brtfs alternative for Mac OS 10.7 Lion which will allow cheap copy-on-write snapshots.

Until Time Machine can take atomic snapshots and efficiently backup large changing files, we need to make database dumps which can be picked up by our backup system. This applies to both PostgreSQL databases and and other large and changing files such as our Solr indexes.

**Update**: To prevent Time Machine from backing up these files you can mark them as excluded either in the Time Machine preference pane or with `xattr`:

{% highlight bash %}
sudo xattr -w com.apple.metadata:com_apple_backup_excludeItem com.apple.backupd /usr/local/var/postgres # [...]
{% endhighlight %}

If you don't exclude these directories from Time Machine, you'll find that your backup increments will be large and you'll quickly lose your history as Time Machine starts pruning old backups to make room. The worst bit is copying those large files every hour will put a noticeable resource strain on your machine.

If you want to audit what Time Machine is backing up (highly recommended if you suspect your backups are larger than they should be), I've found the easiest way is TimeTracker from [CharlesSoft](http://www.charlessoft.com/) (the makers of the handy Pacifist tool). I found I had to run it under `sudo` with the Time Machine backup mounted to avoid errors.

I have a backup script which I run daily. It archives PostgreSQL databases and Solr indexes locally and then `rsync`s them along with my Git repos to an offsite VPS. Since we're archiving locally, we might as well send these same backups offsite.
If your databases are large you might want to look into [continuous archiving](http://stackoverflow.com/questions/2094963/postgresql-improving-pg-dump-pg-restore-performance) to create incremental backups. Be sure to perform full [base backups](http://www.postgresql.org/docs/9.0/static/continuous-archiving.html#BACKUP-BASE-BACKUP) regularly with any incremental setup (I recommend weekly).

The script makes use of my [`lib_exclusive_lock`](https://github.com/jasoncodes/scripts/blob/master/lib_exclusive_lock.sh) functions to prevent concurrent executions. With sufficiently large databases and a slow enough upstream this becomes a problem.

PostgreSQL databases are detected by querying the [`pg_database`](http://www.postgresql.org/docs/9.0/static/catalog-pg-database.html) catalog. Solr instances and their paths are detected by looking for the `solr/home` environment variable in the Tomcat contexts. You'll need to `brew install xmlstarlet` for this to work.

Note: unlike the rest of this guide, this backup script assumes GNU tools are installed as the default.

To use the script, save it as `~root/bin/backup` and add a crontab entry for root (`sudo crontab -e`) like `15 0 * * * ~/bin/backup`. Adjust the configuration variables at the top to suit.

{% highlight bash %}
#!/bin/bash -e
set -o pipefail
export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin

BWLIMIT=30
ARCHIVE_COUNT=5
REMOTE_HOST=backup@example.net

# grab lock
cd "`dirname "$0"`"
source "lib_exclusive_lock.sh"
exclusive_lock_require

# prepare backup directory
umask 0077
mkdir -p ~/backups
cd ~/backups

# compact git repos
find ~git/repositories -maxdepth 1 -type d -name '*.git' | while read REPO
do
  (
    cd $REPO
    git gc --auto --quiet
  )
done

# backup PostgreSQL databases
mkdir -p postgres
su - postgres -lc "psql -q -A -t" <<SQL |
SELECT datname
FROM pg_database
WHERE datname NOT LIKE 'template%';
SQL
while read DB_NAME
do
  mkdir -p "postgres/${DB_NAME}"
  FILENAME="postgres/${DB_NAME}/${DB_NAME}_`date +%Y%m%d`.sql.bz2"
  nice su - postgres -lc "pg_dump --format=p $DB_NAME" | nice bzip2 > "${FILENAME}.new"
  mv "${FILENAME}"{.new,}
  find "postgres/${DB_NAME}" -maxdepth 1 -type f -name "${DB_NAME}_*.sql.*" | sort -r | tail -n +$((ARCHIVE_COUNT + 1)) | xargs -r rm
done

# backup Solr indexes
xml sel -t -v "Context/@path " -o " " -v "Context/Environment[@name='solr/home']/@value" /usr/local/tomcat/conf/Catalina/localhost/*.xml | while read CONTEXT_PATH SOLR_HOME
do
  if [ -n "$CONTEXT_PATH" -a -n "$SOLR_HOME" ]
  then
    DB_NAME="$(basename "$CONTEXT_PATH" | sed -e 's/-production-solr$//')"
    mkdir -p ~/"backups/solr/${DB_NAME}"
    FILENAME=~/"backups/solr/${DB_NAME}/${DB_NAME}_$(date +%Y%m%d).tar.bz2"
    rm -rf "$SOLR_HOME".bak
    cp -lr "$SOLR_HOME"{,.bak}
    (cd "${SOLR_HOME}.bak" && nice tar c .) | nice bzip2 > "${FILENAME}.new"
    rm -rf "$SOLR_HOME".bak
    mv "${FILENAME}"{.new,}
    find "solr/${DB_NAME}" -maxdepth 1 -type f -name "${DB_NAME}_*.tar.bz2" | sort -r | tail -n +$((ARCHIVE_COUNT + 1)) | xargs -r rm
  fi
done

# rsync with a retry. sometimes there's intermittent connectivity issues.
function do_rsync()
{
  if ! rsync --archive --delete-after --partial-dir=.partial --bwlimit $BWLIMIT "$@"
  then
    echo rsync failed: "$@"
    sleep 5m
    echo retrying...
    rsync --archive --delete-after --partial-dir=.partial --bwlimit $BWLIMIT "$@"
    echo retried.
  fi
}

# copy backups offsite

do_rsync ~git/repositories/ $REMOTE_HOST:~/backups/git/

find ~/backups/postgres/* -maxdepth 0 -type d | while read DIR
do
  do_rsync "$DIR" "$REMOTE_HOST:~/backups/postgres/"
done

find ~/backups/solr/* -maxdepth 0 -type d | while read DIR
do
  do_rsync "$DIR" "$REMOTE_HOST:~/backups/solr/"
done
{% endhighlight %}


# Applications [apps]

## Automating application deployment with Capistrano [capistrano]

The [Capistrano Wiki](https://github.com/capistrano/capistrano/wiki) covers the basics on how to setup Capistrano. There are a few gotchas to watch out for however.

The documentation for [RVM](http://rvm.beginrescueend.com/integration/capistrano/) and [Bundler](http://gembundler.com/deploying.html) cover setting up Capistrano support pretty well. Other than requiring the right files, the only other thing you should need to do is disable `sudo` with `set :use_sudo, false`.

For the remote cache to work (`set :deploy_via, :remote_cache`), you'll need to enable SSH agent forwarding with `ssh_options[:forward_agent] = true`. This allows the app user on the server to temporarily use your SSH key to authenticate to your Git repository when deploying.

Here's a complete Capistrano recipe (`config/deploy.rb`):

{% highlight ruby %}
require 'bundler/capistrano'

$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require 'rvm/capistrano'

set :application, 'example' # change me
set :server_name, 'server' # change me
set :user, 'example' # change me
set(:deploy_to) { "~/apps/#{application}/#{stage}" }
set :keep_releases, 5
set(:releases) { capture("ls -x #{releases_path}").split.sort }

set :scm, :git
set :repository, "git@#{server_name}:#{application}.git"
set :branch, "master"
set :deploy_via, :remote_cache

ssh_options[:forward_agent] = true
set :use_sudo, false

role :web, server_name
role :app, server_name
role :db, server_name, :primary => true

namespace :deploy do
  task :start do
  end

  task :stop do
  end

  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

before "deploy:symlink", "deploy:migrate"
after "deploy:update", "deploy:cleanup"
{% endhighlight %}

## Setting up the application environment [app-user]

With your application configured to deploy via Capistrano, you can prepare the new application environment (user account, database, vhost) with the following script. Save a copy as `/usr/local/bin/createapp` and `chmod +x` it:

{% highlight bash %}
#!/bin/bash -e
APPNAME=${1:?Specify application name}
DOMAIN=${2:-${APPNAME}.com}

# create user account
sudo adduser $APPNAME
# copy over admin public key
sudo -u $APPNAME -i bash -c 'umask 0077 > /dev/null && mkdir -p ~/.ssh/ && cat >> ~/.ssh/authorized_keys' < ~/.ssh/authorized_keys
# seed SSH known hosts with git server details
sudo -u $APPNAME -i bash -c 'umask 0077 > /dev/null && mkdir -p ~/.ssh/ && echo "$(hostname -s) $(cat /etc/ssh_host_rsa_key.pub)" >> ~/.ssh/known_hosts'
# install dotfiles
sudo -u $APPNAME -i bash < <( curl -sL http://github.com/jasoncodes/dotfiles/raw/master/install.sh )
# forward mail to root
echo root | sudo -u $APPNAME -i bash -c 'cat > ~/.forward'

# create PostgreSQL database
createuser -SDR $APPNAME
createdb -O $APPNAME ${APPNAME}_production

# setup vhost
sudo cp /etc/apache2/other/vhosts-example.conf.template /etc/apache2/other/vhosts-${APPNAME}-production.conf
sudo /usr/bin/sed -i '' -e s/example\.com/${DOMAIN}/g -e s/example/${APPNAME}/g /etc/apache2/other/vhosts-${APPNAME}-production.conf
sudo -e /etc/apache2/other/vhosts-${APPNAME}-production.conf # check config, make any custom tweaks
sudo apachectl configtest && sudo apachectl graceful

# setup log rotation
sudo cp /etc/logrotate.d/vhosts-example.conf.template /etc/logrotate.d/vhosts-${APPNAME}-production.conf
sudo /usr/bin/sed -i '' s/example/${APPNAME}/g /etc/logrotate.d/vhosts-${APPNAME}-production.conf
{% endhighlight %}

## Deploying your application [deploying]

From within the app directory on your workstation you can then run the following:

{% highlight bash %}
# prepare application directories for deployment
cap deploy:setup
# deploy the application
cap deploy
{% endhighlight %}
