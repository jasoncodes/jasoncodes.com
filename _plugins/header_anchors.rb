require 'active_support'
require 'active_support/core_ext/module/aliasing'

# convert `## Foo Bar [example]` to `<h2 id="example">Foo Bar</h2>`
class Jekyll::MarkdownConverter
  def convert_with_header_anchors(content)
    html = convert_without_header_anchors(content)
    html.gsub! %r[^<(h\d+)[^>]*>(.*) \[([^\]]+)\]</\1>], '<\1 id="\3">\2</\1>'
    html
  end
  alias_method_chain :convert, :header_anchors
end
