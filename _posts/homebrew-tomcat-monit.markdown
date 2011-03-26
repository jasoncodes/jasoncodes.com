---
layout: post
title: Restarting Tomcat automatically on Mac OS with Monit
short: tomcat-monit
date: 2011-02-14
---

When I setup [Tomcat on Mac OS with Homebrew](/posts/mac-os-rails-server#tomcat) I also setup [Monit](/posts/mac-os-rails-server#monit) to monitor if daemons fail. What I didn't do is tell Monit how to restart Tomcat should it fail.

Unfortunately it's often not just a simple case of bouncing Tomcat with `launchctl` when something goes wrong. This is especially the case with Tomcat as we're running it via a launch script. If `launchd` times out and kills the script process, any frozen Java process will stay running. That process will still be holding open port 8080 and will prevent a new instance from starting.

I came up with the following shell script to restart Tomcat fully, even if the Java process has frozen. The script asks `launchd` for what PID it is managing (the `catalina.sh` script) and then kills its direct children (the Java process). First we try with a normal `kill` and then fall back on a `kill -9` if it won't die. Once the existing process is dead, we can bounce the service with `launchctl`. Finally, we wait a few seconds to ensure the service has finished starting back up before we return control back to Monit.

Save the following as `/usr/local/sbin/tomcat-restart` and `chmod +x` it:

{% highlight bash %}
#!/bin/bash -e
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin

TEMPFILE="`mktemp -t tomcat-restart.XXXXXX`"
trap '{ rm -f "$TEMPFILE"; }' EXIT

if launchctl list -x org.apache.tomcat 2> $TEMPFILE
then
  ln "$TEMPFILE" "$TEMPFILE.plist"
  BASE_PID=$(defaults read "$TEMPFILE" PID 2> /dev/null || true)
  rm "$TEMPFILE.plist"
  
  CHILD_PID="$(ps -axo pid,ppid | awk "{ if ( \$2 == \"$BASE_PID\" ) { print \$1 }}")"
  
  if ! [ -z "$CHILD_PID" ]
  then
    echo "Killing Tomcat softly..."
    kill $CHILD_PID
    sleep 2
    if kill -0 $CHILD_PID 2> /dev/null
    then
      sleep 2
    fi
    if kill -0 $CHILD_PID 2> /dev/null
    then
      echo "It's not dead yet. Waiting a little longer..."
      sleep 5
    fi
    if kill -0 $CHILD_PID 2> /dev/null
    then
      echo "Nuking from orbit..."
      kill -9 $CHILD_PID $BASE_PID
    fi
  fi
  
fi

echo "Reversing the polarity..."
sudo launchctl unload -w /Library/LaunchDaemons/org.apache.tomcat.plist || echo "It's dead Jim."
sudo launchctl load -w /Library/LaunchDaemons/org.apache.tomcat.plist || echo "I can't revive it."

if ! curl --connect-timeout 5 --max-time 5 --silent localhost:8080 > /dev/null
then
  echo "Waiting for launch..."
  sleep 5
fi
if ! curl --connect-timeout 5 --max-time 5 --silent localhost:8080 > /dev/null
then
  echo "Not ready yet..."
  sleep 5
fi
if ! curl --connect-timeout 5 --max-time 5 --silent localhost:8080 > /dev/null
then
  echo "It's broken."
  exit 1
fi

echo Done.
{% endhighlight %}

Then all we have to do is tell Monit to run this script when the service fails. My updated service entry for Tomcat in `/etc/monitrc` is as follows:

{% highlight text %}
check host tomcat with address 127.0.0.1
  if failed port 8080
    send "HEAD / HTTP/1.0\r\n\r\n"
    expect "HTTP/1.1"
    with timeout 5 seconds
    then exec "/usr/local/sbin/tomcat-restart"
{% endhighlight %}

Check the syntax is valid and then reload Monit:

{% highlight bash %}
sudo monit -t
sudo monit reload
{% endhighlight %}
