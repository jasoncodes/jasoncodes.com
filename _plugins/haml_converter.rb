require 'active_support'
require 'active_support/core_ext/module/aliasing'

module Jekyll
  require 'haml'
  class HamlConverter < Converter
    safe true
    priority :low

    def matches(ext)
      ext =~ /haml/i
    end

    def output_ext(ext)
      ".html"
    end

    def convert(content)
      engine = Haml::Engine.new(content)
      engine.render
    end
  end

  require 'sass'
  class SassConverter < Converter
    safe true
    priority :low

    def matches(ext)
      ext =~ /sass/i
    end

    def output_ext(ext)
      ".css"
    end

    def convert(content)
      engine = Sass::Engine.new(content)
      engine.render
    end
  end

  class StaticFile
    attr_reader :site, :base, :dir, :name
  end

  class Site
    def read_directories_with_sass(dir = '')
      read_directories_without_sass(dir)
      sass_files, self.static_files = self.static_files.partition { |sf| sf.name =~ /\.(sass|scss)$/ }
      self.pages += sass_files.map do |sf|
        Page.new sf.site, sf.base, sf.dir, sf.name
      end
    end
    alias_method_chain :read_directories, :sass
  end
end
