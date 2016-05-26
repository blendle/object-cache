# frozen_string_literal: true

require 'digest/sha1'
require 'object/cache/version'

# Caching of objects in a Redis store
class Cache
  DEFAULT_TTL = (7 * 24 * 60 * 60) # 1 week

  class << self
    attr_accessor :backend

    # new
    #
    # Finds the correct value (based on the provided key) in the cache store, or
    # calls the original code, and stores the result in cache.
    #
    # The TTL of the cached content is provided with the optional `ttl` named
    # argument. If left blank, the `DEFAULT_TTL` ttl value will be used.
    #
    # The caching key will be determined by creating a SHA digest of the
    # original code's file location and line number within that file. This makes
    # it easier to provide short caching keys like uid's, or ids, and still
    # receive a unique caching key under which the data is stored.
    #
    # The cache key can optionally be left blank. This should **only be done**
    # if the provided data by the method will never changes based on some form
    # of input.
    #
    # For example: caching an `Item` should _always_ be done by providing a
    # unique item identifier as the caching key, otherwise the cache will return
    # the same item every time, even if a different one is stored the second
    # time.
    #
    # good:
    #
    #   Cache.new { 'hello world' } # stored object is always the same
    #   Cache.new(item.id) { item } # stored item is namespaced using its id
    #
    # bad:
    #
    #   Cache.new { item } # item is only stored once, and then always
    #                      # retrieved, even if it is a different item
    #
    def new(key = nil, ttl: DEFAULT_TTL)
      return yield unless replica

      key = Digest::SHA1.hexdigest([key, Proc.new.source_location].flatten.join)[0..5]

      if (cached_value = replica.get(key)).nil?
        yield.tap { |value| update_cache(key, value, ttl: ttl) }
      else
        Marshal.load(cached_value)
      end
    rescue TypeError
      # if `TypeError` is raised, the data could not be Marshal dumped. In that
      # case, delete anything left in the cache store, and get the data without
      # caching.
      #
      delete(key)
      yield
    rescue
      yield
    end

    def include?(key)
      replica.exists(key)
    rescue
      false
    end

    def delete(key)
      return false unless include?(key)

      primary.del(key)
      true
    end

    def update_cache(key, value, ttl: DEFAULT_TTL)
      return unless primary && (value = Marshal.dump(value))

      ttl.to_i.zero? ? primary.set(key, value) : primary.setex(key, ttl.to_i, value)
    end

    def primary
      backend.is_a?(Hash) ? backend[:primary] : backend
    end

    def replicas
      [backend.is_a?(Hash) ? backend[:replicas] : backend].flatten
    end

    def replica
      replicas.sample
    end
  end
end
