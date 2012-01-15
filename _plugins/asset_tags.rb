require 'active_support'
require 'active_support/core_ext/module/aliasing'

module Jekyll
  class Site
    attr_accessor :current_page
  end
  module Convertible
    def do_layout_with_current_page(payload, layouts)
      begin
        self.site.current_page = self
        do_layout_without_current_page(payload, layouts)
      ensure
        self.site.current_page = nil
      end
    end
    alias_method_chain :do_layout, :current_page
  end

  class StaticFile
    def write_with_timestamp(dest)
      write_without_timestamp(dest).tap do |result|
        File.utime self.mtime, self.mtime, destination(dest) if result
      end
    end
    alias_method_chain :write, :timestamp
  end

  class AssetTag < Liquid::Tag
    def initialize(tag_name, params, tokens)
      super
      unless params =~ /\A(\S+)( .*)?\z/
        raise SyntaxError.new("Syntax Error in #{tag_name}: #{params.inspect}")
      end
      @name = $1
      @extra = $2
      @name.gsub!(%r[^/], '')
    end

    def find_asset(context)
      page = context.registers[:site].current_page
      prefixes = []
      prefixes << "posts/#{page.slug}/" if page.is_a? Post
      prefixes << path_prefix
      prefixes.each do |prefix|
        ([nil] + extensions).each do |ext|
          remote_path = "#{prefix}#{@name}#{ext}"
          local_path = File.join context.registers[:site].source, remote_path
          return [local_path, "/#{remote_path}"] if File.exists? local_path
        end
      end
      [nil, "#{path_prefix}#{@name}"]
    end

    def calculate_timestamp(context)
      @timestamp = if @local_path && File.exists?(@local_path)
        File.mtime(@local_path).to_i
      else
        warn "#{@tag_name} '#{@name}' not found"
        nil
      end
    end

    def render(context)
      @local_path, @remote_path = find_asset(context)
      calculate_timestamp context
      render_tag
    end

    def suffix
      @timestamp ? "?#{@timestamp}" : ""
    end

    def path_prefix
      nil
    end

    def extensions
      []
    end

    def render_tag
      "#{@remote_path}#{suffix}"
    end
  end

  class LinkTag < AssetTag
    def render_tag
      %Q{<link href="#{@remote_path}#{suffix}"#{@extra}/>}
    end
  end

  class StylesheetTag < AssetTag
    def path_prefix
      "stylesheets/"
    end

    def extensions
      %w(.css .sass .scss)
    end

    def calculate_timestamp(context)
      super

      # find the page this tag is being rendered in
      site = context.registers[:site]
      page = site.pages.detect do |p|
        @local_path == p.instance_eval { File.join(@base, @dir, @name) }
      end

      # if we have a page object (i.e. we are dynamically renderered)
      if page
        # render the page if it isn't already rendered
        if page.output.nil?
          page = page.clone # we need a clone as rendering isn't idempotent
          page.render site.layouts, site.site_payload
        end

        # extract timestamps out of rendered page
        asset_timestamps = page.output.scan(%r[url\(["'][^"']+\?(\d+)["']\)]).map(&:first).map(&:to_i)

        # pick the latest timestamp
        @timestamp = ([@timestamp] + asset_timestamps).max
      end
    end

    def render_tag
      %Q{<link rel="stylesheet" type="text/css" href="#{@remote_path.gsub(/\.\S+$/,'')}.css#{suffix}"#{@extra || ' media="screen"'}/>}
    end
  end

  class ImageTag < AssetTag
    def path_prefix
      "images/"
    end

    def extensions
      %w(.png .jpg .jpeg)
    end

    def render_tag
      %Q{<img src="#{@remote_path}#{suffix}"#{@extra}/>}
    end
  end

  class JavascriptTag < AssetTag
    def path_prefix
      "javascripts/"
    end

    def extensions
      %w(.js)
    end

    def render_tag
      %Q{<script src="#{@remote_path}#{suffix}"#{@extra.rstrip}></script>}
    end
  end
end

Liquid::Template.register_tag('asset', Jekyll::AssetTag)
Liquid::Template.register_tag('link', Jekyll::LinkTag)
Liquid::Template.register_tag('stylesheet', Jekyll::StylesheetTag)
Liquid::Template.register_tag('image', Jekyll::ImageTag)
Liquid::Template.register_tag('javascript', Jekyll::JavascriptTag)
