require 'pygments'
require 'rack/utils'
require 'active_support/core_ext/hash/indifferent_access'

module Jekyll::Converters::Markdown::RedcarpetParser::WithPygments
  remove_method :block_code
  def block_code(code, lang)
    options = Rack::Utils.parse_query(lang.to_s.split('#', 2)[1]).with_indifferent_access
    lang = lang && lang.split('#').first || "text"

    options.merge! encoding: 'utf-8', nowrap: true
    options[:hl_lines] = options[:hl_lines].to_s.split(',').map { |part|
      if part =~ /\A(\d+)-(\d+)\z/
        ($1.to_i..$2.to_i).to_a
      else
        part
      end
    }.flatten

    html = Pygments.highlight(code, lexer: lang, options: options)

    # move whole of <span class="hll"/> onto single line
    html.gsub! %r[(<span class="hll">)([^\n]*)(\n)(</span>)], '\1\2\4\3'

    # wrap each line in <code/> so we can style them easier
    html.gsub!(/^.*$/, '<code>\0</code>')

    # insert newline into empty <code/> lines to ensure blank lines copy into clipboard
    html.gsub!(%r[^(<code>)(</code>)$], "\\1\n\\2")

    # convert <span class="hll"/> into <strong/> and add styling hook to <code/>
    html.gsub! %r[^<code><span class="hll">(.*)</span></code>$], '<code class="hll"><strong>\1</strong></code>'

    # wrap the result in a <pre/> with our desired CSS classes
    "<pre class=\"source source-#{lang}\">#{html}</pre>"
  end
end
