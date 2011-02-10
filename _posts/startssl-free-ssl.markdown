---
layout: post
title: A free SSL certificate for your web server
short: startssl
date: 2010-12-11
---

# No more self-signed certificates

Typically for a low volume site where verified identity is not import one would use a self-signed certificate for SSL. Unfortunately these triggers security warnings in browsers and require you to recognise/remember checksums to prevent man-in-the-middle attacks when accessing your own servers over HTTPS.

[StartSSL][startssl] offers free domain verified SSL server certificates which work pretty much everywhere. The only real downside is they have a 1 year expiry. This means you need to create a new one every year rather than say a 10 year self-signed certificate which will probably last the life of your server.

These free certificates are also chained which means configuration can be a little tricky as there are a few traps you can fall into. If you don't setup the chain correctly on your server you can run into compatibility issues with clients that may not be immediately obvious. These include either forgetting to setup the chain or creating the links in the wrong order. With either of these errors I myself could still access the site fine.

And that's where this post comes in. I need to setup a couple of new certificates and this time I'm making notes on on the steps I'm taking, referencing my existing setup as I go. At worst I'll save some time next year when I have to renew these certificates. Hopefully you'll find this useful as well.

[startssl]: https://startssl.com/

# Setting it all up

I run Debian stable on my servers. At the time of writing this is Debian Lenny with Apache 2.2.9. Substitute `example.com` for your domain name where applicable.

## Authenticating with StartSSL

Note: As of the time of writing, Chrome has some issues with SSL client certificates which will cause you problems. I recommend using Safari (or Firefox if that's your thing).

If this is your first time using [StartSSL][startssl], you'll need to create an account. Click on Control Panel and then on Sign-up. Fill out all the details and you'll get an SSL client certificate which you use to authenticate with the website.

The client certificate expires after a year so you'll have to create a new one when it comes time to renew your server certificate. StartSSL will send you an email when both are coming up for renewal. To create a new client certificate, first reverify your email address under Validations Wizard: Email Address Validation and then create a new certificate under Certificates Wizard

## Requesting a server certificate

Validations Wizard: Domain Name Validation
Certificates Wizard: Web Server SSL/TLS Certificate

    openssl req -new -newkey rsa:4096 -days 365 -nodes -keyout example.com.key -out example.com.csr

Pick the CSR option when prompted and upload the contents of `example.com.csr`. You will also be prompted for a hostname underneath your domain. I run a [no-www](http://no-www.org/) shop so I used my server's hostname (`host.example.com`). If you want to run `www.example.com`, enter `www` here.

As of this point the `.csr` file is no longer required and can be removed. Alternatively you could generate a CSR with a longer expiry and reuse it next year.

And now we wait for certificate to be issued. This usually happens within the half hour. When you receive the certificate signing confirmation email, download the following certificates:

1. Toolbox > Retrieve Certificate: You will see your newly created certificate. Save it as `example.com.crt`.
2. Toolbox > StartCom CA Certificates: Download "StartCom Root CA (PEM encoded)" (ca.pem)
3. Toolbox > StartCom CA Certificates: Download "Class 1 Intermediate Server CA" (sub.class1.server.ca.pem).

Copy the `.crt`, `.key` and `.pem` files to `/etc/apache2/ssl` on your server.

## Configuring Apache

Run the following commands as root:

{% highlight text %}
cd /etc/apache2/ssl
mv ca.pem startssl.ca.crt
mv sub.class1.server.ca.pem startssl.sub.class1.server.ca.crt
cat startssl.sub.class1.server.ca.crt startssl.ca.crt > startssl.chain.class1.server.crt
cat example.com.{key,crt} startssl.chain.class1.server.crt > example.com.pem
ln -sf example.com.pem apache.pem
chown root:ssl *.crt *.key *.pem
chmod 640 *.key *.pem
{% endhighlight %}

Edit `/etc/apache2/sites-available/ssl` and add the following within the `<VirtualHost>` block:

{% highlight apache %}
SSLEngine On
SSLCertificateFile /etc/apache2/ssl/example.com.crt
SSLCertificateKeyFile /etc/apache2/ssl/example.com.key
SSLCertificateChainFile /etc/apache2/ssl/startssl.chain.class1.server.crt
{% endhighlight %}

At this point you'll want to configure the rest of Apache for SSL if you haven't already.

Check that your Apache config parses as valid:

    apache2ctl -t

And then restart Apache with the new config:

    /etc/init.d/apache2 reload

## Verifying everything worked

Run the following after restarting Apache to check the certificate chain:

    echo HEAD / | openssl s_client -connect localhost:443 -quiet > /dev/null

You should see something like:

{% highlight text %}
depth=2 /C=IL/O=StartCom Ltd./OU=Secure Digital Certificate Signing/CN=StartCom Certification Authority
verify error:num=19:self signed certificate in certificate chain
verify return:0
{% endhighlight %}

A depth of 2 and a return value of 0 is good. If the certificate chain is wrong, you'll probably see something like:

{% highlight text %}
depth=0 /description=12345-ABCDEF123456/C=XX/O=Persona Not Validated/OU=StartCom Free Certificate Member/CN=host.example.com/emailAddress=hostmaster@example.com
verify error:num=20:unable to get local issuer certificate
verify return:1
depth=0 /description=12345-ABCDEF123456/C=XX/O=Persona Not Validated/OU=StartCom Free Certificate Member/CN=host.example.com/emailAddress=hostmaster@example.com
verify error:num=27:certificate not trusted
verify return:1
depth=0 /description=12345-ABCDEF123456/C=XX/O=Persona Not Validated/OU=StartCom Free Certificate Member/CN=host.example.com/emailAddress=hostmaster@example.com
verify error:num=21:unable to verify the first certificate
verify return:1
{% endhighlight %}

## Hosting email services over SSL

I have one host setup to send and receive email using Exim 4 for SMTP and Courier for IMAP. To have these services use your new SSL certificate, point them to your existing certificate files:

{% highlight text %}
ln -sf /etc/apache2/ssl/example.com.pem /etc/courier/imapd.pem
ln -sf /etc/apache2/ssl/example.com.pem /etc/courier/pop3d.pem

ln -sf /etc/apache2/ssl/example.com.pem /etc/exim4/exim.pem
ln -sf /etc/apache2/ssl/example.com.crt /etc/exim4/exim.crt
ln -sf /etc/apache2/ssl/example.com.key /etc/exim4/exim.key
{% endhighlight %}

Outlook and Outlook Express are both fairly broken but fortunately I found some workarounds. You'll want to set the following config option for Exim (in `/etc/exim4/conf.d/main/03_exim4-config_tlsoptions` if you are using split configuration on Debian):

{% highlight bash %}
# Outlook Express really sucks
# See <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=482012>
MAIN_TLS_TRY_VERIFY_HOSTS=''

MAIN_TLS_CERTKEY = CONFDIR/exim.pem
{% endhighlight %}

Outlook does not work properly with the altname in the certificate. You may have to use the servers hostname (`host.example.com`) rather than the domain name (`example.com`).
