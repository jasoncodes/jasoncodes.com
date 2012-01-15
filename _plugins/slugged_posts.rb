require 'active_support'
require 'active_support/core_ext/module/aliasing'

class Jekyll::Post
  def to_liquid_with_slug
    to_liquid_without_slug.merge('slug' => self.slug)
  end
  alias_method_chain :to_liquid, :slug
end
