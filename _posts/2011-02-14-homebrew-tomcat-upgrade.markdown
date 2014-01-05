---
layout: post
title: Upgrading Tomcat with Homebrew
short: tomcat
---

If you followed my guide on setting up [Tomcat on Mac OS with Homebrew](/posts/mac-os-rails-server#tomcat), at some point you may want to update Tomcat to the latest version.

You could stop remove the old version, install the new version, update the symlink then restart the service. You might even get away with leaving the restart to the end. I prefer to install the new version side by side and then flip the symlink just before restarting. This leaves a much smaller downtime window and makes rolling back really easy.

The first step is to update your local formula with the new version info by running the following:

{% highlight bash %}
brew edit tomcat
{% endhighlight %}

Here's the change I made to move from 7.0.6 to 7.0.8:

{% highlight diff %}
diff --git a/Library/Formula/tomcat.rb b/Library/Formula/tomcat.rb
index 90b3443..bded504 100644
--- a/Library/Formula/tomcat.rb
+++ b/Library/Formula/tomcat.rb
@@ -1,9 +1,9 @@
 require 'formula'
 
 class Tomcat <Formula
-  url 'http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.6/bin/apache-tomcat-7.0.6.tar.gz'
+  url 'http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.8/bin/apache-tomcat-7.0.8.tar.gz'
   homepage 'http://tomcat.apache.org/'
-  md5 '1c54578e2e695212ab3ed75170930df4'
+  md5 'b18b0f1d987f82038a7afeb2e3075511'
 
   skip_clean :all
{% endhighlight %}

After the formula is updated you can install the new version with:

{% highlight bash %}
brew install tomcat
{% endhighlight %}

As per the [initial install](/posts/mac-os-rails-server#tomcat), Homebrew links the keg which results in a handful of generically named scripts being added to your path. We'll need to unlink it.

If you try to unlink with `brew unlink tomcat` you'll get `Error: tomcat has multiple installed versions`. It seems the `brew` command doesn't really like multiple versions of the same formula being installed at the same time and it presently doesn't expose a way to do this other than removing the old version first. We can however unlink it by calling the Homebrew API directly:

{% highlight bash %}
ruby -I/usr/local/Library/Homebrew -rglobal -rkeg -e 'puts Keg.new("/usr/local/Cellar/tomcat/7.0.8").unlink'
{% endhighlight %}

The next step is to switch out the `libexec` symlink:

{% highlight bash %}
sudo -u tomcat ln -sf /usr/local/Cellar/tomcat/7.0.8/libexec /usr/local/tomcat/
{% endhighlight %}

And then restart the service:

{% highlight bash %}
sudo launchctl unload -w /Library/LaunchDaemons/org.apache.tomcat.plist
sudo launchctl load -w /Library/LaunchDaemons/org.apache.tomcat.plist
{% endhighlight %}

If all goes well, remove the old version (via the API to workaround the `brew` limitation with multiple versions):

{% highlight bash %}
ruby -I/usr/local/Library/Homebrew -rglobal -rkeg -e 'k = Keg.new("/usr/local/Cellar/tomcat/7.0.6"); puts k.unlink; k.uninstall'
{% endhighlight %}
