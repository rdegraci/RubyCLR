# This file contains the core functionality of the RubyCLR bridge. It can freely
# call all methods in both the RbDynamicMethod and C++ Runtime libraries, but
# you must be very careful about trying to use higher-level abstractions in this
# file since it is very easy to cause a circular dependency on some lower-level
# code. 

require 'Runtime'
require 'generate'

include RubyClr 
include RbDynamicMethod

SYSTEM_PATH = "#{ENV['FrameworkDir']}\\#{ENV['FrameworkVersion']}\\"

NON_GENERIC_TYPE             = -1
GENERIC_AND_NON_GENERIC_TYPE = 0

ConstructorInfo = Struct.new(:member_id, :member_type, :clr_type, :signatures)
MemberInfo = Struct.new(:member_id, :member_type, :member_name, :return_types,
                        :clr_type, :ruby_member_name, :signatures, :is_virtual,
                        :ruby_class, :class_that_defines_member)

module ClrClassInstanceMethods
  def initialize(*params)
    if self.class.instance_variable_get('@is_generic') and self.class.instance_variable_get('@is_generic_type_definition')
      raise "Must use #{self.class.name}.of(Type).new to create a generic type."
    else
      ctor_info = get_constructor_info(self.class)
  
      case ctor_info.member_type
      when 'ctor':     Generate::ctor_shim(self.class, ctor_info)
      when 'fastctor': Generate::fastctor_shim(self.class, ctor_info)
      end
      
      initialize(*params)
    end
  end

  alias alias_method_missing method_missing

  def import(name, &block)
    member_info = get_instance_member_info(Identifier::to_camel_case(name.to_s), name.to_s, block_given?)

    case member_info.member_type
    when 'method':       Generate::method_shim(self.class, member_info)
    when 'fastmethod':   Generate::fastmethod_shim(self.class, member_info)
    when 'property':     Generate::method_shim(self.class, member_info)
    when 'fastproperty': Generate::fastmethod_shim(self.class, member_info)
    when 'array':        Generate::fastmethod_shim(self.class, member_info)
    when 'event':        Generate::event_shim(self.class, self, member_info, false, &block)
    when 'field':        Generate::field_shim(self.class, member_info)
    end

    member_info
  end

  def method_missing(method_name, *method_params, &block)
    member_info = import(method_name, &block)
    self.send member_info.ruby_member_name, *method_params if member_info.member_type != 'event'
  end
end

module ClrClassStaticMethods
  attr_reader :value_type_size, :clr_type_name
  
  def is_value_type?
    @is_value_type
  end
  
  def is_enum?
    @is_enum
  end

  def is_generic?
    @is_generic
  end

  def to_s
    name.gsub('::', '.')
  end

  # This method does a complex thing: given a namespace name like
  # System.Data.Class.NestedClass it walks backwards and replaces any "." with
  # "+" if it refers to a nested class. In this example, it will return
  # System.Data.Class+NestedClass
  
  # THERE is a bug in this method with nested enums
  # DispatchTests::Color::Red is eval'd to DispatchTests::Color+Red instead of
  # DispatchTests+Color::Red
  
  def correct_namespace_for_nested_classes(namespace)
    names = namespace.split('::')
    return namespace if names.length == 1

    working_namespace   = names.first
    corrected_namespace = names.first
    
    1.upto(names.length - 1) do |i|
      working_namespace  += '::' + names[i]

      element   = eval(working_namespace)
      separator = (element.instance_of?(Class) and
                   element.instance_variable_get('@is_nested')) ? '+' : '.'

      corrected_namespace += separator + names[i]
    end
    corrected_namespace
  end

  # This method gets called to resolve missing constants for nested types only
  def const_missing(symbol)
    clr_type_name, array_rank = parse_clr_class_reference(symbol.to_s)

    clr_namespace = correct_namespace_for_nested_classes(name)
    clr_type      = clr_namespace + '+' + clr_type_name
    clr_type     += "[#{',' * (array_rank - 1)}]" if array_rank > 0

    klass = create_clr_class_object(clr_type)
    klass.instance_variable_set('@event_refs', [])
    klass.is_enum? ? generate_enum_class_object(symbol, klass) : generate_class_object(klass)

    self.const_set(symbol, klass)
  end
  
  def import(name, &block)
    static_member_info = get_static_member_info(Identifier::to_camel_case(name.to_s), name.to_s, block_given?)

    case static_member_info.member_type
    when 'method':       Generate::static_method_shim(self, static_member_info)
    when 'fastmethod':   Generate::static_fastmethod_shim(self, static_member_info)
    when 'fastproperty': Generate::static_fastmethod_shim(self, static_member_info)
    when 'event':        Generate::event_shim(self, self.clr_type, static_member_info, true, &block)
    when 'field':        Generate::static_field_shim(self, static_member_info)
    when 'property':     raise 'Overloaded static properties are not supported by RubyCLR'
    end

    static_member_info
  end

  def method_missing(static_method_name, *static_method_params, &block)
    static_member_info = import(static_method_name, &block)
    self.send static_member_info.member_name, *static_method_params if static_member_info.member_type != 'event'
  end
end

module ClrEnumerator
  include Enumerable
  def each
    enum = self.as(System::Collections::IEnumerable).get_enumerator.as(System::Collections::IEnumerator)
    while enum.move_next
      yield(enum.current)
    end
  end
end

module ClrComparable
  def <(other)
    self.as(System::IComparable).compare_to(other) == -1
  end
  
  def >(other)
    self.as(System::IComparable).compare_to(other) == 1
  end
  
  def ==(other)
    self.as(System::IComparable).compare_to(other) == 0
  end
  
  def <=>(other)
    self.as(System::IComparable).compare_to(other)
  end
end

module ClrComparableOfT
  def <(other)
    self.as(System::IComparable.of(self)).compare_to(other) == -1
  end
  
  def >(other)
    self.as(System::IComparable.of(self)).compare_to(other) == 1
  end
  
  def ==(other)
    self.as(System::IComparable.of(self)).compare_to(other) == 0
  end

  def <=>(other)
    self.as(System::IComparable.of(self)).compare_to(other)
  end
end

module ClrClassGenericMethods
private
  def get_class_name
    i = name.rindex('::')
    if i == nil
      return Object, name
    else
      namespace_name = name
      return eval(name[0..i - 1]), name[i + 2..name.length]
    end
  end

public
  def of(*types)
    clr_module, class_name = get_class_name
    clr_type_name          = "#{name.gsub('::', '.')}`#{types.length}"
    type_names             = types.collect { |type| type.clr_type.name }
    ruby_class_name        = "#{class_name}_generic_#{type_names.join('_')}"

    if clr_module.const_defined?(ruby_class_name)
      clr_module.const_get(ruby_class_name)
    else
      klass = create_clr_generic_type(clr_type_name, ruby_class_name, *types)
      generate_class_object(klass)
      clr_module.const_set(ruby_class_name, klass)
      klass
    end
  end
end

module InterfaceHelpers
  def clr_interfaces
    self.class.clr_interfaces
  end
end

class Module
  def implements(*interfaces)
    unless respond_to?(:clr_interfaces)
      instance_eval <<-EOF
        def clr_interfaces
          #{self.name}.clr_interfaces=([]) unless #{self.name}.instance_variables.include?('@clr_interfaces')
          #{self.name}.instance_variable_get(:@clr_interfaces)
        end
        def clr_interfaces=(value)
          #{self.name}.instance_variable_set(:@clr_interfaces, value)
        end
      EOF
    end
    (self.clr_interfaces += interfaces.collect { |interface| interface.to_s }).sort
    include InterfaceHelpers
  end

  def get_module_type_name_defined_in(type_name)
    ancestors.each { |a|
      return a, a.clr_type_names[type_name] if a.clr_type_names.has_key?(type_name) 
    }
    return nil, 0
  end

  alias alias_const_missing const_missing

  # TODO: refactor common code between this and Class#const_missing!
  def const_missing(symbol)
    clr_type_name, array_rank       = parse_clr_class_reference(symbol.to_s)
    clr_module, generic_param_count = get_module_type_name_defined_in(clr_type_name)
    return alias_const_missing(symbol) if clr_module == nil 

    if clr_module.name == 'Object'
      clr_type      = clr_type_name
    else
      clr_namespace = clr_module.name.gsub('::', '.')
      clr_type      = clr_namespace + '.' + clr_type_name
    end
    clr_type     += "[#{',' * (array_rank - 1)}]" if array_rank > 0

    if generic_param_count == NON_GENERIC_TYPE
      klass = create_clr_class_object(clr_type)
      klass.is_enum? ? generate_enum_class_object(symbol, klass) :
                       generate_class_object(klass)
    else
      klass = if generic_param_count == GENERIC_AND_NON_GENERIC_TYPE
        create_clr_class_object(clr_type)
      else
        c = Class.new
        c.instance_variable_set('@is_generic', true)
        c.instance_variable_set('@is_generic_type_definition', true)
        c
      end
      generate_class_object(klass)
      klass.extend ClrClassGenericMethods
    end

    clr_module.const_set(symbol, klass)
  end

  # This method de-mangles names - will add generics parsing to this later
  def parse_clr_class_reference(symbol)
    r = /(.*)_array_(\d+)/.match(symbol.to_s)
    return symbol, 0 if r == nil
    return r[1], Integer(r[2])
  end

  def generate_enum_class_object(symbol, klass)
    # TODO: rename values and lookup hashes to meaningful names
    klass.class_eval %{
      def self.initialize_lookups(hash, symbol_lookup)
        @@values = hash
        @@lookup = symbol_lookup
      end
      
      def self.lookup(value)
        @@lookup.has_key?(value) ? @@lookup[value] : #{symbol}.new(value)
      end
      
      def initialize(value)
        @value = value
      end
      
      def +(rhs)
        #{symbol}.new(@value + rhs)
      end
      
      def -(rhs)
        #{symbol}.new(@value - rhs)
      end
      
      def |(rhs)
        return #{symbol}.new(@value | rhs.to_i) if rhs.instance_of?(#{symbol})
        return #{symbol}.new(@value | rhs)      if rhs.instance_of?(Fixnum)
        raise 'Enum bitwise or operator can only work with ' + #{symbol} + ' or Fixnum types'
      end
      
      def to_i
        @value
      end
      
      def to_s
        @@values.has_key?(@value) ? @@values[@value] : @value.to_s
      end
      
      def ==(rhs)
        @value == rhs.to_i
      end
    }

    enum_names  = get_enum_names(klass)
    enum_values = get_enum_values(klass)
    raise "Should never happen: names and values counts for #{clr_type} do not match" if enum_names.length != enum_values.length
    
    hash, symbol_lookup = {}, {}
    0.upto(enum_names.length - 1) do |i|
      hash[enum_values[i]]          = enum_names[i]
      enum_instance                 = klass.new(enum_values[i])
      symbol_lookup[enum_values[i]] = enum_instance
      klass.const_set(enum_names[i], enum_instance)
    end
    klass.initialize_lookups(hash, symbol_lookup)
  end

  def generate_class_object(klass)
    klass.class_eval %{
      include #{RubyClr::instance_mixins.join(',')}
      extend  #{RubyClr::static_mixins.join(',')}
    }
  end
end

class Object
  def clr_type_names
    @clr_type_names ||= {}
  end

  def type_name_set(type_name, generic_param_count = 0)
    @clr_type_names ||= {}
    if @clr_type_names.has_key?(type_name) 
      @clr_type_names[type_name] = GENERIC_AND_NON_GENERIC_TYPE 
    else
      @clr_type_names[type_name] = generic_param_count == 0 ? NON_GENERIC_TYPE : generic_param_count
    end
  end

  def reference(assembly_name)
    RubyClr::reference(assembly_name)
  end
  
  def reference_file(assembly_path)
    RubyClr::reference_file(assembly_path)
  end
end

module RubyClr
  @@type_ref_re                = /^(([\w0-9\_\.]+)\.)?([\w0-9\_]+)$/
  @@simple_generic_type_ref_re = /^([\w0-9\_\.]+)\.([\w0-9\_]+)\`(\d+)$/
  @@instance_mixins            = [ClrClassInstanceMethods]
  @@static_mixins              = [ClrClassStaticMethods]
  
  def self.register_instance_mixins(instance_module)
    @@instance_mixins << instance_module
  end
  
  def self.register_static_mixins(static_module)
    @@static_mixins << static_module
  end

  def self.instance_mixins
    @@instance_mixins
  end
  
  def self.static_mixins
    @@static_mixins
  end
  
  def self.get_namespace(namespace)
    scope = Object
    namespace.split('.').each do |n|
      n = n[0..0].capitalize + n[1..n.length]
      scope = scope.const_defined?(n) ? scope.const_get(n) : scope.const_set(n, Module.new)
    end
    scope
  end

  def self.generate_modules(class_names)
    class_names.each do |c|
      m = @@type_ref_re.match(c)
      if m != nil
        namespaces, type_name = m[2], m[3]
        begin
          if namespaces == nil
            scope = Object
          else
            scope = get_namespace(namespaces)
          end
          scope.type_name_set(type_name) if scope != nil
        rescue
          # Parse errors are all related to namespace names that begin with a
          # lowercase letter (e.g. std). Constant names in Ruby MUST begin with
          # a capital letter. Should I force mandatory capitalization along with
          # case insensitive comparisons in the runtime code???
        end
      elsif (m = @@simple_generic_type_ref_re.match(c)) != nil
        namespaces, type_name, param_count = m[1], m[2], m[3]
        scope = get_namespace(namespaces)
        scope.type_name_set(type_name, param_count) if scope != nil
      else
        # no namespace - now must disambiguate between a nested class and a type at global scope
#        puts "A type without a namespace #{c}"
      end
    end
  end

  def self.init
    RbDynamicMethod::register_macro_module(RubyClrMacros)
    @@loaded_assemblies = get_names_of_loaded_assemblies
    generate_modules(get_types_in_loaded_assemblies)
    reference('System.Xml')
  end

  def self.reference(assembly_name)
    if @@loaded_assemblies.include?(assembly_name)
      false
    else
      generate_modules(internal_reference(assembly_name))
      @@loaded_assemblies << assembly_name
      true
    end
  end

  def self.list_assemblies
    @@loaded_assemblies 
  end
  
  def self.reference_file(assembly_path)
    @@assembly_filenames ||= []
    if @@assembly_filenames.include?(assembly_path)
      false
    else
      generate_modules(internal_reference_file(assembly_path))
      @@assembly_filenames << assembly_path
      true
    end
  end
end

RubyClr::init
