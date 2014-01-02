---
layout: post
title: Installing Exim on Mac OS X
short: exim
date: 2013-12-31
updated: 2014-01-02
---

Why replace Postfix with Exim when Postfix comes pre-installed with Mac OS X?

For a long time I had been using [Postfix on my Macs](/posts/mac-os-rails-server#email) to forward emails from cron jobs, etc. to my main email account. Since upgrading to Mavericks however, I found this to be less reliable than I would have liked. For various reasons, I send all outbound email via a smart host and Postfix has decided that sometimes it will ignore that setting and try direct delivery. The best part is that it seems to still try sending on the SMTP submission port (TCP 587) when doing this (rather than using TCP 25). Something’s broken and I’ve given up trying to fix it. I’ve decided to replace Postfix with something I know and trust: Exim.

My experience with Exim to date has been almost exclusively on Debian where the packagers have done a great job at making it easy to configure. `dpkg-reconfigure exim4-config` is pretty awesome. Luckily though, with a little bit of playing around and referencing the [manual](http://www.exim.org/exim-html-current/doc/html/spec_html/index.html), it’s not too hard to get Exim going on Mac OS X.

Here we go. :)

**Update 2014-01-02**: Added section on [Enabling IPv6 support](#ipv6)

**Update 2014-01-02**: Added section on [Postfix `sendmail` compatibility](#postfix-sendmail-compat)

# Installing Exim [installation]

## Creating a service user account [user_account]

It’s best to run Exim under a dedicated user account. You can create one though the Users & Groups preference pane, but that will leave you with an additional user account showing up in the user interface. Since you’ll never log into this account interactively, it’s better to create a new system account instead. Unfortunately, Mac OS X does not come with a simple command line tool to create user accounts and instead multiple calls to `dscl` are required. The good news is that I have wrapped this all up into a shell script which I’ve called [`adduser`](https://github.com/jasoncodes/dotfiles/blob/master/bin/adduser).

You can install this utility in one of two ways: The first is to download the script file manually, place it somewhere in your path (e.g. `~/bin`) and then `chmod +x` it. The second, easier way is to use [`fresh`](https://github.com/freshshell/fresh). `fresh` is a tool for managing your dotfiles and it works great for utility scripts. With fresh installed, you can simply run `fresh https://github.com/jasoncodes/dotfiles/blob/master/bin/adduser` and `adduser` will be installed.

## Homebrew [homebrew]

[Homebrew](http://brew.sh/) is a package manager for OS X. We could install Exim manually from source but Homebrew makes it so much easier. You probably want to install it now if you haven’t already.

## Installing Exim [install]

Create a user account for Exim, brew the formula, and set file permissions for the dedicated user account:

{% highlight bash %}
sudo adduser exim
USER=ref:exim brew install exim
sudo chown root /usr/local/etc/exim.conf
sudo cp -ai /usr/local/etc/exim.conf{,.org}
sudo chown exim /usr/local/var/spool/exim
sudo mkdir -p /usr/local/var/spool/exim
sudo chown exim:admin /usr/local/var/spool/exim
sudo chmod 750 /usr/local/var/spool/exim
{% endhighlight %}

### 404 Not Found [404]

Note: If you get a "Download failed" error when trying to `brew install` Exim, you can grab a copy of `exim-4.80.1.tar.gz` from somewhere else (to Google!) and drop it into `/Library/Caches/Homebrew`. Re-running `brew install` will then use this pre-cached copy. A great thing to note about Homebrew is that it will checksum the downloaded file to make sure it matches the original source file the formula creator used.

## Configuring Exim [configuration]

Open `/usr/local/etc/exim.conf` in your preferred text editor. Note that you’ll need to be able to write to this file as root. `sudo vim /usr/local/etc/exim.conf` is one way to do this but I prefer [`vim-eunuch`](https://github.com/tpope/vim-eunuch)’s `:SudoWrite`.

### Local Hostname [hostname]

For machines which are always on a single network with their hostname configured in DNS, the output of `hostname` should be both predicable and stable. For mobile machines which roam between networks (e.g. laptops), you’ll probably have better reliability if you tell Exim which hostname you’d like to use when referring to your local machine.

To set the hostname which Exim uses, search for `primary_hostname` in the configuration file, uncomment the line and set the value to the full hostname of your machine. e.g. `example.local`.

### Block external access [interfaces]

Exim by default denies relay attempts but it’s still good policy to not expose services when you don’t need to. To prevent Exim from listening on all network interfaces, add the following after the `primary_hostname` entry:

{% highlight text %}
local_interfaces = 127.0.0.1
{% endhighlight %}

### Postfix `sendmail` compatibility [postfix-sendmail-compat]

Exim and Postfix have different default behaviours for sendmail’s `-t` option which used by default by Rails’ (ActionMailer) sendmail delivery method. This option extracts email addresses from the message headers. When additional email addresses are supplied on the command line, Postfix adds these to the extracted set. Exim’s default is to remove any addresses specified on the command line from the extracted set. Rails expects Postfix’s behaviour. Add the following to the main configuration section (after `local_interfaces` is fine):

{% highlight text %}
extract_addresses_remove_arguments = false
{% endhighlight %}

Exim also adds a `Sender` header when using `sendmail` with a custom `From` address. One generally does not want this behaviour as the `Sender` header is often displayed in email clients. You can always tell what user account sent an email by examining the `Received` headers. Add the following to disable this behaviour:

{% highlight text %}
no_local_from_check
{% endhighlight %}

### Routers [routers]

Search for `begin routers`. This section controls how mail is routed to its destination. We want to send all mail via a smarthost rather than using the default behaviour of delivering directly to destination mail servers via MX entries.

Comment out the existing `dnslookup` router entry and add a new entry below it to route via a smarthost:

{% highlight text %}
smart_route:
  driver = manualroute
  domains = !+local_domains
  transport = smarthost
  route_list = * smtp.example.net::587
{% endhighlight %}

Replace `smtp.example.net` with your upstream SMTP smarthost server’s hostname.

### Transports [transports]

Search for `begin transports`. This section controls how mail is delivered once a destination is found by the router. Notice the "transport" setting in the router configuration. We want to force TLS (encryption) and use authentication (when required) for the target smarthost.

Add a new smarthost transport below the `remote_smtp` entry:

{% highlight text %}
smarthost:
  driver = smtp
  hosts_require_tls = *
  hosts_require_auth = ${lookup{$host}nwildlsearch{/usr/local/etc/exim/passwd.client}{*}}
{% endhighlight %}

### Authentication [authenticators]

Search for `begin authenticators`. This section controls where authentication credentials are retrieved from for both inbound (server) and outbound (client) connections. We're only authenticating as a client here so here's an entry to add which retrieves the username and password from our configuration file:

{% highlight text %}
plain:
  driver = plaintext
  public_name = PLAIN
  client_send = "^${extract{1}{::}{${lookup{$host}lsearch*{/usr/local/etc/exim/passwd.client}{$value}fail}}}\
                 ^${extract{2}{::}{${lookup{$host}lsearch*{/usr/local/etc/exim/passwd.client}{$value}fail}}}"
{% endhighlight %}

Next, we’ll create a secured password file to store the credentials for our smarthost.

{% highlight bash %}
sudo mkdir /usr/local/etc/exim
sudo touch /usr/local/etc/exim/passwd.client
sudo chmod 600 /usr/local/etc/exim/passwd.client
sudo chown exim /usr/local/etc/exim/passwd.client
{% endhighlight %}

Add a line like the following to `/usr/local/etc/exim/passwd.client`, replacing the placeholders with your smarthost’s hostname, username, and password:

{% highlight text %}
smtp.example.net:username:password
{% endhighlight %}

### Forwarding local user accounts [forward]

Create `.forward` files in the home directory of any local accounts you want to receive mail for. The file should contain a single line with the destination email address.

### Enabling IPv6 support [ipv6]

Exim’s IPv6 support is not enabled out of the box. If you’re interested in this, it’s fairly easy to get going.

We’ll first have to edit the Homebrew formula to compile Exim with IPv6 support enabled. Run `brew edit exim` and add `s << "HAVE_IPV6=yes\n"` to the end of the `inreplace 'Local/Makefile'` block. Run `brew uninstall exim` to remove the IPv4 version and then re-run `USER=ref:exim brew install exim` to install the IPv6 enabled version.

Secondly, we’ll add the IPv6 loopback address to the allowed list for relaying. Search for `relay_from_hosts` and change the value to `<; 127.0.0.1 ; ::1`.

Finally, we’ll add the IPv6 loopback interface to the list of interfaces to listen to. Search for `local_interfaces` and change the value to `<; 127.0.0.1 ; ::1`.

### Syntax check config file [check]

Run `sudo exim -bV` to check the syntax of the config file. Any major errors will be detected by this command. If all is good, you should see `Configuration file is /usr/local/etc/exim.conf` as the last line of output.

## Running Exim on port 25 [port25]

If you have any other SMTP server running, you should disable it now. If you followed my previous [Postfix on OS X guide](), you can do this by running `sudo launchctl unload -w /Library/LaunchDaemons/org.postfix.master.plist`.

Create the following launchd daemon configuration file at `/Library/LaunchDaemons/exim.plist`:

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>exim</string>
  <key>UserName</key>
  <string>root</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/exim</string>
    <string>-bdf</string>
    <string>-q30m</string>
  </array>
  <key>RunAtLoad</key>
  <true />
  <key>KeepAlive</key>
  <true />
</dict>
</plist>
{% endhighlight %}

Start the server now by running `sudo launchctl load -w /Library/LaunchDaemons/exim.plist`.

Run `nc -n 127.0.0.1 25 < /dev/null` and you should see a 220 banner message confirming the server is now running.

## Replace Postfix `sendmail` with Exim [sendmail]

UNIX services such as `cron` use sendmail rather than using SMTP to deliver mail. In order for these to work, we’ll need to swap out Postfix’s sendmail binary (`/usr/sbin/sendmail`) for Exim.

{% highlight bash %}
sudo mv -i /usr/sbin/sendmail{,.org}
sudo ln -s /usr/local/bin/exim /usr/sbin/sendmail
sudo chown root:wheel /usr/sbin/sendmail
sudo chmod u+s /usr/sbin/sendmail
{% endhighlight %}

## Log rotation [logrotate]

The main log file for Exim is stored at `/usr/local/var/spool/exim/log/mainlog`. You can view this file if you wish to see detail on what Exim is doing.

Exim comes with a tool to perform log rotation. Let’s setup a launchd schedule to rotate the logs once a day. Create `/Library/LaunchDaemons/exim-logrotate.plist` with the following:

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>exim-logrotate</string>
  <key>UserName</key>
  <string>root</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/exicyclog</string>
    <string>-k</string>
    <string>30</string>
  </array>
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

Register the log rotation job with launchctl by running `sudo launchctl load -w /Library/LaunchDaemons/exim-logrotate.plist`.

# Testing [testing]

You can test sendmail is working by sending a test message using `mail`. Assuming you setup a `.forward` file earlier for your user account, the following should send you an email:

{% highlight bash %}
date | mail -s Test $USER
{% endhighlight %}

If you receive this test email, you’re done! Yay!
