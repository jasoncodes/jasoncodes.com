---
layout: post
title: Clean Google Analytics tracking data from your URLs
short: ga
updated: 2013-01-07
---

FeedBurner has a feature which integrates with Google Analytics to tell you how many of your hits come via feed readers. This is rather useful because feed readers typically don't pass any useful referrer information (especially desktop clients). This tracking can be enabled by ticking the "[Track clicks as a traffic source in Google Analytics](http://www.google.com/support/feedburner/bin/answer.py?hl=en&answer=165769)" option in your FeedBurner account.

However, this comes with a disadvantage to those of us who care about clean URLs. I'm sure I'm not the only one who dislikes seeing otherwise clean URLs polluted with Google Analytics tracking data:

    http://example.com/posts/foo-bar?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed:+example

You may even add `utm_source=twitter` to short URLs when you post to Twitter in addition to tracking your feeds. Either way, a big problem with this is that these URLs are often shared around and not everybody takes the time to remove all the cruft and share the clean canonical URL.

Luckily Google Analytics [asynchronous tracking](http://code.google.com/apis/analytics/docs/tracking/asyncTracking.html) provides a nice little API that lets us [queue a function](http://code.google.com/apis/analytics/docs/tracking/asyncUsageGuide.html#PushingFunctions) to be ran after the tracking request has been sent. This combined with the [`history.replaceState`](https://developer.mozilla.org/en/DOM/Manipulating_the_browser_history#The_replaceState%28%29.c2.a0method) method in HTML5 lets us remove the the tracking data from the URL without reloading the page or breaking the browser's history. Another win for modern browsers.

The additional code required to make this happen is one extra statement to be added to your Google Analytics tracking JavaScript:

{% highlight javascript hl_lines=4-7 %}
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-XXXXX-X']);
_gaq.push(['_trackPageview']);
_gaq.push(function() {
  var newPath = location.pathname + location.search.replace(/[?&]utm_[^?&]+/g, "").replace(/^&/, "?") + location.hash;
  if (history.replaceState) history.replaceState(null, '', newPath);
});

(function() {
  var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
  ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
  var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
{% endhighlight %}

**Update 2011-01-26:** I originally called `replaceState` with just `location.pathname` but that resulted in the removal of anchors within a page (e.g. links to comments). The code has been updated to `location.pathname + location.hash` to keep anchors. e.g. `/foo/bar?utm_medium=example#comment-42` will now be replaced with `/foo/bar#comment-42`.

**Update 2013-01-07:** Thanks [Henrik Nyh](http://henrik.nyh.se/) for a [patch](#comment-758637324) to preserve parameters other than those used by Google Analytics.
