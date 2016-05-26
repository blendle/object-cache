# frozen_string_literal: true
require 'object/cache'

# :no-doc:
class Object
  def cache(key = nil, **options, &block)
    block = -> { self } unless block_given?

    Cache.new(key, **options, &block)
  end
end
