# frozen_string_literal: true

require 'object/cache'

# :no-doc:
module Kernel
  def cache(key = nil, **options, &block)
    Cache.new(key, **options, &block)
  end
end
