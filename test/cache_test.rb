# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'mock_redis'
require 'object/cache'
require 'minitest/autorun'

# :no-doc:
class CacheTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def setup
    Cache.backend = MockRedis.new
    Cache.default_ttl = 604_800
  end

  def redis
    Cache.primary
  end

  def key_to_value(key)
    Marshal.load(redis.get(key))
  end

  def test_cache_returns_object
    assert_equal('hello world', Cache.new { 'hello world' })
  end

  def test_cache_stores_object
    Cache.new { 'hello world' }
    assert redis.keys.one?
  end

  def test_cache_stores_correct_value
    assert_equal Cache.new { 'hello world' }, key_to_value(redis.keys.first)
  end

  def test_does_not_cache_non_marshalable_objects
    Cache.new { -> { 'hello world' } }
    assert redis.keys.empty?
  end

  def test_return_original_value_for_non_marshalable_objects
    assert_equal 'hello world', Cache.new { -> { 'hello world' } }.call
  end

  def test_returns_cache_on_same_file_line_without_custom_key
    Cache.new { 'hello world' } && Cache.new { 'hello universe' }
    assert_equal 'hello world', key_to_value(redis.keys.first)
  end

  def test_store_multiple_objects_cached_in_same_file_but_different_lines
    Cache.new { 'hello world' }
    Cache.new { 'hello universe' }

    assert_equal 'hello world', key_to_value(redis.keys.first)
    assert_equal 'hello universe', key_to_value(redis.keys.last)
  end

  def test_custom_cache_key_on_same_file_and_line
    Cache.new('hello') { 'world' } && Cache.new('hi') { 'world' }
    assert_equal 2, redis.keys.count
  end

  def test_custom_cache_key_on_same_file_but_different_lines
    Cache.new('hello') { 'world' }
    Cache.new('hi') { 'world' }
    assert_equal 2, redis.keys.count
  end

  def test_cache_without_ttl
    Cache.new(ttl: nil) { 'hello world' }
    assert_equal(-1, redis.ttl(redis.keys.first))
  end

  def test_cache_without_ttl_using_zero
    Cache.new(ttl: 0) { 'hello world' }
    assert_equal(-1, redis.ttl(redis.keys.first))
  end

  def test_cache_default_ttl
    Cache.new { 'hello world' }
    assert_equal Cache.default_ttl, redis.ttl(redis.keys.first)
  end

  def test_cache_custom_default_ttl
    Cache.default_ttl = 60
    Cache.new { 'hello world' }
    assert_equal 60, redis.ttl(redis.keys.first)
  end

  def test_cache_with_ttl
    Cache.new(ttl: 60) { 'hello world' }
    assert_equal 60, redis.ttl(redis.keys.first)
  end

  def test_core_extension
    load 'object/cache/core_extension.rb'
    assert_equal('hello world', cache { 'hello world' })
    assert Kernel.send(:remove_method, :cache)
  end

  def test_core_extension_options
    load 'object/cache/core_extension.rb'
    cache(ttl: 60) { 'hello world' }
    assert_equal 60, redis.ttl(redis.keys.first)
    assert Kernel.send(:remove_method, :cache)
  end

  def test_backend_with_replicas
    Cache.backend = { primary: redis, replicas: [redis, redis] }

    Cache.new { 'hello world' } && assert_equal('hello world', Cache.new { 'hello world' })
  end

  def test_backend_with_primary_without_replicas
    Cache.backend = { primary: MockRedis.new }

    Cache.new { 'hello world' } && assert_equal('hello world', Cache.new { 'hello world' })
  end

  def test_backend_with_primary_and_single_replica
    redis = MockRedis.new
    Cache.backend = { primary: redis, replicas: redis }

    Cache.new { 'hello world' } && assert_equal('hello world', Cache.new { 'hello world' })
  end

  def test_backend_with_replicas_not_having_primary_data
    primary = MockRedis.new
    replica = MockRedis.new
    Cache.backend = { primary: primary, replicas: replica }

    Cache.new { 'hello world' } && Cache.new { 'hello world' }

    assert_equal 1, primary.keys.count
    assert_equal 0, replica.keys.count
  end

  def test_default_key_prefix_custom
    Cache.default_key_prefix = 'hello'

    Cache.new { 'hello world' }
    assert_match(/^hello/, redis.keys.first)
  end

  def test_default_key_prefix_method_name
    Cache.default_key_prefix = :method_name

    Cache.new { 'hello world' }
    assert_match(/^test_default_key_prefix_method_name/, redis.keys.first)
  end

  def test_default_key_prefix_class_name
    Cache.default_key_prefix = :class_name

    Cache.new { 'hello world' }
    assert_match(/^CacheTest/, redis.keys.first)
  end

  def test_key_prefix_custom
    Cache.new(key_prefix: 'hello') { 'hello world' }
    assert_match(/^hello/, redis.keys.first)
  end

  def test_key_prefix_method_name
    Cache.new(key_prefix: :method_name) { 'hello world' }
    assert_match(/^test_key_prefix_method_name/, redis.keys.first)
  end

  def test_key_prefix_class_name
    Cache.new(key_prefix: :class_name) { 'hello world' }
    assert_match(/^CacheTest/, redis.keys.first)
  end

  def test_unset_backend
    Cache.backend = nil
    val = 0
    block = -> { val += 1 }
    Cache.new(&block)
    Cache.backend = MockRedis.new

    assert_equal 1, val
  end

  def test_unset_backend_raising_type_error
    Cache.backend = nil
    val = 0
    begin
      Cache.new do
        val += 1
        raise TypeError
      end
    rescue
      nil
    end

    Cache.backend = MockRedis.new
    assert_equal 1, val
  end

  def test_single_yield_on_failure
    val = 0
    begin
      Cache.new do
        val += 1
        raise TypeError
      end
    rescue
      nil
    end

    assert_equal 1, val
  end

  def test_yield_when_marshal_load_fails
    testing = -> { Cache.new(key_prefix: 'marshal') { 'hello world' } }

    assert_equal 'hello world', testing.call
    redis.set(redis.keys('marshal*').first, 'garbage')
    assert_equal 'hello world', testing.call
    assert_empty redis.keys('marshal*')
  end
end
