require 'rouge'
require 'nokogiri'

module KramdownConverterHtmlPatch
  def convert_codeblock(el, indent)
    if lang_tokens = el.options[:lang]&.split('#', 2)
      el.options[:lang] = lang_tokens[0]
      el.options.merge! Rack::Utils.parse_query(lang_tokens[1]).transform_keys(&:to_sym)
    end

    classNames = %w[source]
    if lang = el.options[:lang]
      classNames << "source-#{lang}"
    end
    el.attr[:class] = classNames.join(' ')

    doc = Nokogiri::HTML.fragment(super)

    node = doc.at('div.source')
    unless node
      raise "Error converting code block: #{el.inspect}"
    end

    node.name = 'pre'

    highlight_lines = el.options[:hl_lines].to_s.split(',').flat_map do |part|
      if part =~ /\A(\d+)-(\d+)\z/
        (Integer($1)..Integer($2)).to_a
      else
        Integer(part)
      end
    end

    lines = node.inner_html.split("\n")
    lines = lines.map.with_index do |line, index|
      highlight = highlight_lines.include?(index + 1)
      "<code#{' class="hll"' if highlight}>#{line}</code>"
    end
    node.inner_html = lines.join("\n")

    doc.to_html
  end
end

Kramdown::Converter::Html.prepend KramdownConverterHtmlPatch
