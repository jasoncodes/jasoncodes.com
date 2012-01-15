require 'active_support'
require 'active_support/core_ext/module/aliasing'

class Jekyll::Post
  def initialize_with_updated(site, source, dir, name)
    initialize_without_updated(site, source, dir, name)
    self.data['updated'] = if self.data.has_key? 'updated'
      Time.parse self.data['updated'].to_s
    end
    self.data['last_modified'] = self.data['updated'] || self.date
  end
  alias_method_chain :initialize, :updated
end
