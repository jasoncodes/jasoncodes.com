---
layout: post
title: Ruby 1.9.2 encoding issues with Rails 2.3.10
date: 2010-12-30
---

While switching my app over from Ruby Enterprise Edition 1.8.7 to Ruby 1.9.2p0, I ran into a few issues with content encodings. The vast majority these issues could be solved by placing `# -*- coding: utf-8 -*-` at the top of the source file. A couple of the problems I ran into ended up being a little more complex.

## UTF-8 form parameters

The first problem was the `params` hash was not arriving to my controllers encoding as UTF-8 but instead as ASCII-8BIT. This is not a problem if all your inputs are ASCII-7 but that's not so for me. With content such as `café` I was getting an exception later on during the request that had become all too familiar to me: `incompatible character encodings: ASCII-8BIT and UTF-8`.

Rails 3 solves this very nicely by doing a number of things including interpreting params as UTF-8 and adding [workaround for Internet Explorer](http://railssnowman.info/). I'll leave the workarounds and `accept-charset="UTF-8"` form attributes as an exercise for the reader. I present to you my monkey-patch to interpret all string params as UTF-8. Save the following as `config/initializers/utf8_params.rb`:

{% highlight ruby %}
raise "Check if this is still needed on " + Rails.version unless Rails.version == '2.3.10'

class ActionController::Base

  def force_utf8_params
    traverse = lambda do |object, block|
      if object.kind_of?(Hash)
        object.each_value { |o| traverse.call(o, block) }
      elsif object.kind_of?(Array)
        object.each { |o| traverse.call(o, block) }
      else
        block.call(object)
      end
      object
    end
    force_encoding = lambda do |o|
      o.force_encoding Encoding::UTF_8 if o.respond_to? :force_encoding
    end
    traverse.call(params, force_encoding)
  end
  before_filter :force_utf8_params
  
end
{% endhighlight %}

## ERB templates

I was having trouble getting the old `# -*- coding: utf-8 -*-` working in ERB and I was wondering if I'd have to start looking into other options. I'd get an exception any time I outputted a string containing UTF-8 (from params or the model). Luckily I came across the following code in [`action_view/template_handlers/erb.rb`](https://github.com/rails/rails/blob/v2.3.10/actionpack/lib/action_view/template_handlers/erb.rb#L14):

{% highlight ruby %}
magic = $1 if template.source =~ /\A(<%#.*coding[:=]\s*(\S+)\s*-?%>)/
erb = "#{magic}<% __in_erb_template=true %>#{template.source}"
{% endhighlight %}

It looks like Rails does support specifying the encoding of ERB templates after all. All you need to do is to add the following to the top of your template:

{% highlight text %}
<%# coding: utf-8 %>
{% endhighlight %}

The key part I was missing is to have no whitespace between the `<%` and `#`. Additionally, if this is in a plain text template for ActionMailer, you'll want to avoid any newlines between this block and your main content otherwise you'll have a blank line at the top of the email.

## Environment variables

I ran into a couple of encoding errors that I was having trouble reproducing locally but were highly reproducible on production (running on Apache with Passenger). It even ran fine when I booted up a `RAILS_ENV=production script/server` on the production host. This had me stumped for a few minutes until I thought to look at my environment variables. A `set | grep UTF` revealed the following:

{% highlight bash %}
LANG=en_AU.UTF-8
LC_CTYPE=en_US.UTF-8
{% endhighlight %}

The bugs reproduced fine once I `unset` these in my local terminal session. Ruby 1.9 can use these environment variables to set the default encoding to something other than US-ASCII. Handy once you know about it. You may want to try running your tests with these unset to see if you're missing any encoding issues.

If you want Ruby to default to UTF-8 when loading files (i.e `File.read`) when these environment variables are not set, add the following to an initializer:

{% highlight ruby %}
Encoding.default_external = 'UTF-8'
{% endhighlight %}
