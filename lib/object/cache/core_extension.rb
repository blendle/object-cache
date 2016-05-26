# frozen_string_literal: true
require 'object/cache'

# :no-doc:
class Object
  def cache(key = nil, **options, &block)
    Cache.new(key, **options, &block)
  end
end
