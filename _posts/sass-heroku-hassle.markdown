---
layout: post
title: Using Sass on Heroku with Hassle
short: sass
date: 2010-12-12
updated: 2011-01-08
---

A little while ago [Lucas Willett](http://developingego.com/) and I hacked together [Compass, Rails 3 and Heroku without a Hassle](http://til.developingego.com/post/1266966478/compass-rails-3-and-heroku-without-a-hassle). This is a combination of three components:

1. Render compiled CSS to `tmp/stylesheets/` instead of `public/stylesheets/` as the file system is [read only](http://docs.heroku.com/constraints#read-only-filesystem) on Heroku.
2. Use `Rack::Static` to mount `tmp/stylesheets` on `/stylesheets` so they're accessible via their original URL.
3. Monkey patch [`ActionView::Helpers::AssetTagHelper`](http://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html) to check `tmp/stylesheets/` for stylesheets in addition to the default of `public/stylesheets/`. This is to ensure cache busting continues to function and you don't unintentionally serve old stylesheets to your users.

The whole reason this workaround came about was that we had some trouble in getting Hassle to work. The problem was around initialisation which wasn't hard to solve in retrospect but I had the hair-brained idea to write the quick workaround above. It worked. The cache busting was an added bonus (of which I would have needed anyway).

One problem though is `Rack::Static` does not fall-through if it doesn't find a file. As a result, this solution does not work if you have existing files in `public/stylesheets/` you want to serve alongside your Sass stylesheets. Luckily for us this wasn't a problem.

However now I am wanting to use this same setup on an existing project which has a mix of both CSS files and Sass stylesheets. The time for the quick hack is over. I have [forked Hassle](https://github.com/jasoncodes/hassle) and added a couple of features from our workaround:

1. [Always run Hassle even when not on Heroku.](https://github.com/jasoncodes/hassle/commit/b2ce7d03b01795a4da5bdbd1447b9c8fe8d82347)
   I didn't want to have `public/` polluted with generated files so I set Hassle to run all the time. This keeps `public/stylesheets/` clean in development mode.

2. [Fix cache busting on Hassle stylesheets.](https://github.com/jasoncodes/hassle/commit/74f9a95ae6273bdc200a46c8bd503fa7704f98a7)
   The monkey patch to ensure Sass stylesheets correctly refresh when you redeploy.

**Update:** I have also made a couple of [tweaks to the HTTP response headers](https://github.com/jasoncodes/hassle/compare/ee74b86...a61495d) to improve the cacheability of the generated stylesheets. By adding a `Last-Modified` header to the response, browsers can use a `If-Modified-Since` header in their request to get a much smaller 304 response if nothing has changed. Ideally browsers will just use the existing `max-age`, but this doesn't happen often enough.

If you'd like to use my fork, add the following to your `Gemfile`:

    gem 'hassle', :git => 'git://github.com/jasoncodes/hassle.git'

We use Hassle in combination with [Compass](http://compass-style.org/) and it's working great.
