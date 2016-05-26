# frozen_string_literal: true

# :no-doc:
class Object
  def cache(key = nil, **options, &block)
    Cache.new(key, **options, &block)
  end
end
