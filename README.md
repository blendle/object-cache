# Object::Cache [![wercker status](https://app.wercker.com/status/8f5b16e230784fd4bd75f267d5d62e85/s/master "wercker status")](https://app.wercker.com/project/bykey/8f5b16e230784fd4bd75f267d5d62e85)

Easy caching of Ruby objects, using [Redis](http://redis.io) as a backend store.

* [Installation](#installation)
* [Quick Start](#quick-start)
* [Usage](#usage)
  * [marshaling data](#marshaling-data)
  * [ttl](#ttl)
  * [namespaced-keys](#namespaced-keys)
  * [redis-replicas](#redis-replicas)
  * [core-extension](#core-extension)
* [License](#license)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'object-cache'
```

And then execute:

```shell
bundle
```

Or install it yourself as:

```shell
gem install object-cache
```

## Quick Start

```ruby
# require the proper libraries in your project
require 'redis'
require 'object/cache'

# set the backend to a new Redis instance
Cache.backend = Redis.new

# wrap your object in a `Cache.new` block to store the object on first usage,
# and retrieve it again on subsequent usages
Cache.new { 'hello world' }

# add the core extension for easier access
require 'object/cache/core_extension'
cache { 'hello world' }
```

## Usage

Using `Object::Cache`, you can cache objects in Ruby that have a heavy cost
attached to initializing them, and then replay the recorded object on any
subsequent requests.

For example, database query results can be cached, or HTTP requests to other
services within your infrastructure.

Caching an object is as easy as wrapping that object in a `Cache.new` block:

```ruby
Cache.new { 'hello world' }
```

Here, the object is of type `String`, but it can be any type of object that can
be marshalled using the Ruby [`Marshal`][marshal] library.

#### marshaling data

You can only marshal _data_, not _code_, so anything that produces code that is
executed later to return data (like Procs) cannot be cached. You can still wrap
those in a `Cache.new` block, and the block will return the Proc as expected,
but no caching will occur, so there's no point in doing so.

#### ttl

By default, a cached object has a `ttl` (time to live) of one week. This means
that every request after the first request uses the value from the cached
object. After one week, the cached value becomes stale, and the first request
after that will again store the (possibly changed) object in the cache store.

You can easily modify the `ttl` using the keyword argument by that same name:

```ruby
Cache.new(ttl: 60) { 'remember me for 60 seconds!' }
```

Or, if you want the cached object to never go stale, disable the TTL entirely:

```ruby
Cache.new(ttl: nil) { 'I am forever in your cache!' }
Cache.new(ttl: 0) { 'me too!' }
```

#### namespaced keys

When storing the key/value object into Redis, the key name is based on the file
name and line number where the cache was initiated. This allows you to cache
objects without specifying any namespacing yourself.

If however, you are storing an object that changes based on input, you need to
add a unique namespace to the cache, to make sure the correct object is returned
from cache:

```ruby
Cache.new(email) { User.find(email: email) }
```

In the above case, we use the customer's email to correctly namespace the
returned object in the cache store. The provided namespace argument is still
merged together with the file name and line number of the cache request, so you
can re-use that same `email` namespace in different locations, without worrying
about any naming collisions.

#### redis replicas

Before, we used the following setup to connect `Object::Cache` to a redis
backend:

```ruby
Cache.backend = Redis.new
```

The Ruby Redis library has primary/replicas support [buit-in using Redis
Sentinel][sentinel].

If however, you have your own setup, and want the writes and reads to be
separated between different Redis instances, you can pass in a hash to the
backend config, with a `primary` and `replicas` key:

```ruby
Cache.backend = { primary: Redis.new, replicas: [Redis.new, Redis.new] }
```

The above example obiously only works if the replicas receive the written data
from the primary instance.

#### core extension

Finally, if you want, you can extend `Object` with a `cache` method, for
convenient access to the cache object:

```ruby
require 'object/cache/core_extension'

# these are the same:
cache('hello', ttl: 60) { 'hello world' }
Cache.new('hello', ttl: 60) { 'hello world' }
```

That's it!

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

[marshal]: http://ruby-doc.org/core-2.3.0/Marshal.html
[sentinel]: https://github.com/redis/redis-rb#sentinel-support
