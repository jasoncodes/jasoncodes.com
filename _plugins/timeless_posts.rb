raise 'Post not loaded' unless defined?(Jekyll::Post)
class Jekyll::Post
  
  # dates in filenames are now optional
  # if omitted, dates must be set in the metadata for published posts
  
  remove_const :MATCHER
  MATCHER = /^(.+\/)*(?:(\d+-\d+-\d+)-)?(.*)(\.[^.]+)$/
  
  def process(name)
    m, cats, date, slug, ext = *name.match(MATCHER)
    self.date = date && Time.parse(date)
    self.slug = slug
    self.ext = ext
  end
  
  def initialize_with_timeless(site, source, dir, name)
    initialize_without_timeless(site, source, dir, name)
    self.published = false if self.date.nil?
  end
  alias_method_chain :initialize, :timeless
  
end
