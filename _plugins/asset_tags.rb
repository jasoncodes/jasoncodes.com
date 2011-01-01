module Jekyll

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
      ([nil] + extensions).each do |ext|
        remote_path = "#{path_prefix}#{@name}#{ext}"
        local_path = File.join context.registers[:site].source, remote_path
        return [local_path, "/#{remote_path}"] if File.exists? local_path
      end
      [nil, "#{path_prefix}#{@name}"]
    end

    def render(context)
      local_path, @remote_path = find_asset(context)
      @suffix = if local_path && File.exists?(local_path)
        "?#{File.mtime(local_path).to_i}"
      else
        warn "#{@tag_name} '#{@name}' not found"
        nil
      end
      render_tag
    end

    def path_prefix
      nil
    end

    def extensions
      []
    end

    def render_tag
      "#{@remote_path}#{@suffix}"
    end
  end

  class LinkTag < AssetTag
    def render_tag
      %Q{<link href="#{@remote_path}#{@suffix}"#{@extra}/>}
    end
  end

  class StylesheetTag < AssetTag
    def path_prefix
      "stylesheets/"
    end
    
    def extensions
      %w(.css .sass .scss)
    end
    
    def render_tag
      %Q{<link rel="stylesheet" type="text/css" href="#{@remote_path.gsub(/\.\S+$/,'')}.css#{@suffix}"#{@extra || ' media="screen"'}/>}
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
      %Q{<img src="#{@remote_path}#{@suffix}"#{@extra}/>}
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
      %Q{<script src="#{@remote_path}#{@suffix}"#{@extra.rstrip}></script>}
    end
  end

end

Liquid::Template.register_tag('asset', Jekyll::AssetTag)
Liquid::Template.register_tag('link', Jekyll::LinkTag)
Liquid::Template.register_tag('stylesheet', Jekyll::StylesheetTag)
Liquid::Template.register_tag('image', Jekyll::ImageTag)
Liquid::Template.register_tag('javascript', Jekyll::JavascriptTag)
