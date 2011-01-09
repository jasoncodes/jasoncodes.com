require 'active_support'
require 'active_support/core_ext/module/aliasing'

class Albino
  
  def colorize(options = {})
    
    # disable the built in <div/> and <pre/> wrappers
    options[:O] = "#{@options[:O]},nowrap=true"
    
    # call the colorizer
    html = execute([@@bin] + convert_options(options))
    
    # wrap each line in <code/> so we can style them easier
    html.gsub!(/^.*$/, '<code>\0</code>')
    
    # wrap the result in a <pre/> with our desired CSS classes
    "<pre class=\"source source-#{@options[:l]}\">#{html}</pre>"
    
  end
  alias_method :to_s, :colorize
  
  def convert_options(options = {})
    @options.merge(options).inject [] do |args, (flag, value)|
      args += ["-#{flag}", "#{value}"]
    end
  end
  
end

class Jekyll::HighlightBlock
  def add_code_tags(code, lang)
    code # noop
  end
end
