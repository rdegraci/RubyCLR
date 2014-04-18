# This file references all meta-level functionality that is built on top
# of the RubyCLR bridge. Code in here can freely use any methods that are
# defined in core.rb or in layers underneath it. This file was created to
# cleanly isolate where core functionality ends and add-on / mix-in
# functionality begins.

require_gem 'activerecord'

require 'bigdecimal'
require 'core'
require 'help'
require 'helpers'

# Uncomment next line to use Object.help feature once you've done a
# gem install text-format
#require 'text/format'

RubyClr::register_instance_mixins(InstanceHelpers)
RubyClr::register_static_mixins(StaticHelpers)

require 'databinding'
require 'compilation'