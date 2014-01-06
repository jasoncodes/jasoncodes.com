require 'redcarpet'
require 'rack/utils'

# convert `## Foo Bar [example]` to `<h2 id="example">Foo Bar</h2>`
class Redcarpet::Render::HTML
  def header(text, level)
    if text =~ /\A(.+) \[([^\]]+)\]\z/
      text = $1
      attrs = " id=\"#{$2}\""
    end
    "\n<h#{level}#{attrs}>#{Rack::Utils.escape_html text}</h#{level}>\n"
  end
end
