---
layout: post
title: Nested resource URLs without controller names or numeric IDs in Rails 3
short: nested
---

Let's say you want your app to have URLs like GitHub's: `https://github.com/mojombo/jekyll`. There are a number of advantages to URLs of this form over more conventional Rails resource URLs:

* Anyone with a vague familiarity with GitHub knows that the first path segment is the username and the second segment is the repository name. Without visiting a GitHub URL you can have a good idea of who owns the repository and what the name of the project is. This also makes remembering and typing URLs manually very easy.

* Repositories are namespaced under accounts. As all repository URLs contain the account name, repository names need only be unique within a single account.

* There are no controller or model names in the URL. A URL such as `https://github.com/accounts/mojombo/repositories/jekyll` would be overly verbose and would add no value.

* Services like GitHub and Twitter allow you to rename accounts. Unfortunately, doing so breaks all existing external links. Out of the box Rails URLs contains numeric IDs which are immutable but aren't overly user friendly. By keeping track of history we can prevent links from breaking when slugs change. [FriendlyId](https://github.com/norman/friendly_id) solves this problem perfectly.

There are a couple of ways to implement URLs like GitHub's in Rails. One way is with a bunch of custom routes. This can easily result in a complex routes configuration file, especially if we nested further resources underneath repositories (such as issues or wiki pages). Care would also need to be taken for route helpers to have decent names.

A far nicer way to implement these kind of URLs is to define nested resources and hide the relevant controller names from the generated paths. This is the approach we will take here. Source code for this post's example app is [available on GitHub](https://github.com/jasoncodes/rails-3-nested-resource-slugs).

Note: This post is for Rails 3. For Rails 2.3, you can use [`default_routing`](https://github.com/caring/default_routing) in combination with [FriendlyId](https://github.com/norman/friendly_id). I have a [fork of `default_routing`](https://github.com/jasoncodes/default_routing) which adds support for Bundler.

# Project setup

## Generate new Rails app [rails-new]

Create a new directory and setup our RVM gemset:

``` bash
mkdir example
cd example
git init
echo rvm --create 1.9.2@example > .rvmrc
cd . # trigger RVM to load the rvmrc file
```

Generate a new Rails 3 app without Test::Unit or Prototype. We'll use RSpec for testing and we can add [`jquery-rails`](https://github.com/indirect/jquery-rails) later when we want to add client-side scripting.

``` bash
rails new . --skip-test-unit --skip-prototype
```

Add [Inherited Resources](https://github.com/josevalim/inherited_resources) and [RSpec](https://github.com/rspec) to the Gemfile. We'll be using these shortly.

``` ruby
gem 'inherited_resources'

group :development, :test do
  gem 'rspec-rails'
end
```

Run `bundle` to ensure all the required gems are installed.

## Create models [models]

Generate our model files and migrations. We'll be nesting projects underneath accounts and each model will have their own name.

``` bash
rails generate model account name:string
rails generate model project name:string account:references
```

At this point we should add database constraints to the migration and validations to the model. For brevity we'll just add the `has_many` association for Account here:

``` ruby
class Account < ActiveRecord::Base
  has_many :projects
end
```

And then run the migrations with `rake db:migrate`.

## Controllers and initial routes [controllers]

Now that our test models are ready, let's add an initial set of routes to `config/routes.rb`:

``` ruby
Example::Application.routes.draw do
  resources :accounts do
    resources :projects
  end
end
```

Add a couple of controllers using Inherited Resources:

``` ruby
class AccountsController < ApplicationController
  inherit_resources
end

class ProjectsController < ApplicationController
  inherit_resources
  belongs_to :account
end
```

We now have URLs of the classic `https://example.com/accounts/3141/projects/59265` format. At this point I have also created specs for the routes which I have omitted here for brevity. You can find these in the [controllers commit](https://github.com/jasoncodes/rails-3-nested-resource-slugs/commit/274a8f34c702afce8e22dcb532eb2c805da4df21) in the [example app repo](https://github.com/jasoncodes/rails-3-nested-resource-slugs).

# Replacing numeric IDs in URLs with slugs [friendly_id]

Revealing our surrogate primary keys in user visible URLs is not overly pretty. Usually there is a name field or other suitable text identifier which we could use. Name fields are rarely suitable for use directly in a URL as they typically contain unsafe characters and are often not unique nor immutable. Luckily for us, there's [FriendlyId](https://github.com/norman/friendly_id) which normalises our name fields and ensures they are unique by adding a sequence number if required. With FriendlyId, we can easily turn URLs from `https://example.com/accounts/3141/projects/59265` into `https://example.com/accounts/foocorp/projects/widgets`.

Add `friendly_id` to the `Gemfile` and run `bundle`:

``` ruby
gem 'friendly_id', '~> 3.2'
```

Next, create the slugs table. This is where FriendlyId stores information on all current and previous slugs to allow existing URLs to continue to function even if we rename an account or project.

In a production app you should [301 redirect any old slugs to the latest slug](http://norman.github.com/friendly_id/file.Guide.html#redirecting_to_the_current_friendly_url) by checking `resource.friendly_id_status.best?` in a `before_filter`. This will prevent search engines from seeing the same content at different URLs.

``` bash
rails generate friendly_id
```

Add a cached slug column to each model table. This is done primarily for performance reasons. This allows FriendlyId to generate URLs without having to recalculate and verify the slug every time.

``` bash
rails generate migration add_cached_slug_to_accounts cached_slug:string
rails generate migration add_cached_slug_to_projects cached_slug:string
```

The `cached_slug` fields will also be preferred for lookups and thus should be indexed together with any parent scope ID.
Ensure you add the relevant indexes to the migration.

``` ruby#hl_lines=4,15
class AddCachedSlugToAccounts < ActiveRecord::Migration
  def self.up
    add_column :accounts, :cached_slug, :string
    add_index :accounts, :cached_slug, :unique => true
  end

  def self.down
    remove_column :accounts, :cached_slug
  end
end

class AddCachedSlugToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :cached_slug, :string
    add_index :projects, [:account_id, :cached_slug], :unique => true
  end

  def self.down
    remove_column :projects, :cached_slug
  end
end
```

Add `has_friendly_id` to the models:

``` ruby
class Account < ActiveRecord::Base
  has_friendly_id :name, :use_slug => true
end
```

``` ruby
class Project < ActiveRecord::Base
  has_friendly_id :name, :use_slug => true, :scope => :account_id
end
```

Run the migrations and generate slugs for any existing records:

``` bash
rake db:migrate
rake friendly_id:make_slugs MODEL=Account
rake friendly_id:make_slugs MODEL=Project
```

# Removing the controller names from URLs [controller-names]

Now that we have URLs like `https://example.com/accounts/foocorp/projects/widgets`, we need to remove the the controller name segments from the path so we end up with URLs like `https://example.com/foocorp/widgets`.

## Updating the specs [specs]

First things first, let's update the routing specs to match the URLs we are after. i.e. `/foocorp/widgets` instead of `/accounts/foocorp/projects/widgets`.

`spec/routing/accounts_routing_spec.rb`:

``` ruby
require 'spec_helper'

describe AccountsController do
  describe "routing" do
    it '/ to Accounts#index' do
      path = accounts_path
      path.should == '/'
      { :get => path }.should route_to(
        :controller => 'accounts',
        :action => 'index'
      )
    end

    it '/new to Account#new' do
      path = new_account_path
      path.should == '/new'
      { :get => path }.should route_to(
        :controller => 'accounts',
        :action => 'new'
      )
    end

    it '/:account_id to Account#show' do
      path = account_path 'foocorp'
      path.should == '/foocorp'
      { :get => path }.should route_to(
        :controller => 'accounts',
        :action => 'show',
        :id => 'foocorp'
      )
    end

    it '/:account_id/edit to Account#edit' do
      path = edit_account_path 'foocorp'
      path.should == '/foocorp/edit'
      { :get => path }.should route_to(
        :controller => 'accounts',
        :action => 'edit',
        :id => 'foocorp'
      )
    end
  end
end
```

`spec/routing/projects_routing_spec.rb`:

``` ruby
require 'spec_helper'

describe ProjectsController do
  describe "routing" do
    it '/:account_id/new to Projects#new' do
      path = new_account_project_path('foocorp')
      path.should == '/foocorp/new'
      { :get => path }.should route_to(
        :controller => 'projects',
        :action => 'new',
        :account_id => 'foocorp'
      )
    end

    it '/:account_id/:project_id to Projects#show' do
      path = account_project_path 'foocorp', 'widgets'
      path.should == '/foocorp/widgets'
      { :get => path }.should route_to(
        :controller => 'projects',
        :action => 'show',
        :account_id => 'foocorp',
        :id => 'widgets'
      )
    end

    it '/:account_id/:project_id/edit to Projects#edit' do
      path = edit_account_project_path 'foocorp', 'widgets'
      path.should == '/foocorp/widgets/edit'
      { :get => path }.should route_to(
        :controller => 'projects',
        :action => 'edit',
        :account_id => 'foocorp',
        :id => 'widgets'
      )
    end
  end
end
```

## Updating the routes [routes]

We can customise the controller names in routes by using the `:path` option on the `resources` block. By setting the path to an empty string, we can remove the controller name segment completely from the generated paths.

With no prefix on the nested resource routes, both the show page for accounts (`/accounts/foocorp`) and the index page for the nested projects (`/accounts/foocorp/projects`) will end up with the same URL (`/foocorp`). Since we can't have both of these at the same URL, we should only generate a route for one of these two actions to prevent confusion and possible bugs. In most cases I've found that disabling the nested index route is best as typically you'd want a normal show page for the parent resource. For example, the project listing makes up only part of the account's show page at `/foocorp`.

Here's the updated routes entries:

``` ruby
Example::Application.routes.draw do
  resources :accounts, :path => '' do
    resources :projects, :path => '', :except => [:index]
  end
end
```

## A small problem [problem]

Unfortunately this does not work quite to plan. If you run the specs, you'll see the member actions on the parent resource are not working. Viewing the output of `rake routes` confirms why:

```
account_project GET    /:account_id/:id(.:format)      {:action=>"show", :controller=>"projects"}
   edit_account GET    /:id/edit(.:format)             {:action=>"edit", :controller=>"accounts"}
```

The nested show route is outputted first and catches all member actions on the parent. If you take a look the implementation of `resources` in  [`action_dispatch/routing/mapper.rb`](https://github.com/rails/rails/blob/v3.0.5/actionpack/lib/action_dispatch/routing/mapper.rb#L1003), you'll see that the child block is `yield`ed before any of the resources own routes are outputted.

## An easy solution [solution]

The workaround for this is to place any nested `resources` which have empty paths (`:path => ''`) within a second parent `resources` block. This second block uses `:only => []` to prevent it from generating any routes of its own. Any `member` or `collection` blocks for `resources :accounts` (as well as any `only`/`except` constraints) can be added as normal to the first `resources :accounts` entry.

``` ruby
Example::Application.routes.draw do
  resources :accounts, :path => ''
  resources :accounts, :path => '', :only => [] do
    resources :projects, :path => '', :except => [:index]
  end
end
```

Voilà, all of the specs are now passing.
