# This file contains helper methods that add functionality to RubyCLR. Code in
# this file can use all features of core.rb and lower layers without
# restriction. There are some features in this file that have dependencies on
# each other, for example, the interface is and as methods are used by the each
# method, so they themselves cannot use each (this is doc'd in the method).

reference 'cscompmgd'
reference 'Microsoft.JScript'

module Identifier
  def self.is_capital?(char)
    return true if char >= 65 and char <= 90
    false
  end

public  
  def self.to_ruby_case(camel_case_string)
    words = []
    offset, index = 0, 0
    camel_case_string.each_byte do |char|
      if is_capital?(char) and index != offset
        words << camel_case_string[offset..index - 1].downcase
        offset = index
      end
      index += 1
    end
    words << camel_case_string[offset..index].downcase
    words.join('_')
  end

  def self.to_camel_case(name)
    frags = name.split('_')
    frags.each { |frag| frag.capitalize! }
    frags.join
  end
end

class Array
  def to_ary_of(type)
    result = Array.of(type).new(self.length)
    self.each_with_index do |item , index|
      result[index] = item
    end
    result
  end
  
  def self.of(*types)
    array_type = types.first
    types.each do |type|
      raise 'All parameter types for Array.of method must be the same' if type != array_type
    end
    array_rank      = types.length
    clr_type        = array_type.clr_type.full_name
    ruby_class_name = "#{clr_type.gsub('.', '::')}_array_#{array_rank}"
    return eval(ruby_class_name)
  end
end

# Methods in this module will be mixed into as instance methods
module InstanceHelpers
private
  def self.internal_list_methods(type, with_params)
    methods = type.get_methods
    map     = {}
    0.upto(methods.length - 1) do |i|
      if with_params
        p = methods[i].get_parameters
        params = []
        0.upto(p.length - 1) do |j|
          params << "#{p[j].parameter_type.full_name} #{p[j].name}"
        end
        map["#{methods[i].name}(#{params.join(', ')})"] = true
      else
        map[methods[i].name] = true
      end
    end
    map.keys.sort
  end

  def self.collect_list(items)
    return items.collect { |item| yield item if block_given? }
  end
  
  def self.internal_list_interfaces(type)
    interfaces = collect_list(type.get_interfaces) { |i| i.full_name }
    interfaces.sort
  end

  def self.internal_list_properties(type)
    properties = collect_list(type.get_properties) do |p|
      description = "#{p.property_type.full_name} #{p.name}"
      description += " read" if p.can_read
      description += " write" if p.can_write
      description
    end
    properties.sort
  end
  
  def self.internal_list_fields(type)
    fields = collect_list(type.get_fields) do |field|
      "#{field.field_type.full_name} #{field.name}" 
    end
    fields.sort
  end
  
  def self.get_parameter_types(parameters)
    parameters.collect { |param| param.parameter_type.full_name }
  end

  def self.internal_list_events(type)
    events = collect_list(type.get_events) do |event|
      return_type = event.event_handler_type.get_method("Invoke").return_type.full_name
      params      = event.event_handler_type.get_method("Invoke").get_parameters
      "#{return_type} #{event.name}(#{get_parameter_types(params).join(', ')})"
    end
  end
  
public  
  def help(method_name = nil)
    if method_name == nil
      Help::get_type_help(clr_type)
    else
      Help::get_member_help(clr_type, method_name)
    end
    nil
  end
  
  def clr_type
    get_clr_type(self.class.instance_variable_get('@clr_type'))
  end

  def list_methods(with_params = false)
    InstanceHelpers::internal_list_methods(clr_type, with_params)
  end

  def list_interfaces
    InstanceHelpers::internal_list_interfaces(clr_type)
  end
  
  def list_properties
    InstanceHelpers::internal_list_properties(clr_type)
  end

  def list_events
    InstanceHelpers::internal_list_events(clr_type)
  end

  def list_fields
    InstanceHelpers::internal_list_fields(clr_type)
  end
  
  alias old_methods methods

  def methods(regular = true)
    old_methods(regular) + list_methods
  end

  alias old_respond_to? respond_to?

  def respond_to?(method)
    result = old_respond_to?(method)
    begin
      result = import(method)
    rescue
      return false
    end
    true
  end

  def internal_get_interface(name)
    clr_type = self.clr_type
    klass    = self.class
    create_safe_ruby_instance_method(klass, 'internal_get_interface') do
      ld_self
      intern             'internal_has_interface?'
      ldc_i4_1
      ld_args
      ldind_i4
      call_ruby_varargs  'rb_funcall', 1
      ldc_Qtrue
      ceq
      brtrue             :match
      
      # Return nil if interface is not found (same behavior as C# operator)
      ldc_i4_Qnil
      ret

      label        :match
      ldstr        name.to_s
      ld_this      klass
      call         'static Marshal::ToRubyObjectAsInterface(String, Object)'
      ret
    end
    internal_get_interface(name)
  end

  def get_interface(name)
    internal_get_interface(name)
  end
  
  alias as get_interface

  def internal_has_interface?(name)
    clr_type = self.clr_type
    klass    = self.class
    create_safe_ruby_instance_method(klass, 'internal_has_interface?') do
      declare            'RuntimeTypeHandle', :type_handle

      ld_args
      ldind_i4
      intern             'clr_type'
      ldc_i4_0
      call_ruby_varargs  'rb_funcall', 0
      call               'static Marshal::ToObjectInternal(VALUE)'
      callvirt           'Type::get_TypeHandle()'
      stloc_s            :type_handle

      # NOTE: cannot use each() here since each is defined using this method!
      interfaces = clr_type.get_interfaces
      0.upto(interfaces.length - 1) do |i|
        interface_name = interfaces[i].full_name
        ldloc_s          :type_handle
        ldtoken          interface_name
        ceq
        brtrue           :match
      end

      ldc_Qfalse
      ret

      label              :match
      ldc_Qtrue
      ret
    end
    internal_has_interface?(name)
  end
  
  def has_interface?(name)
    internal_has_interface?(name)
  end

  alias is? has_interface?
end

# Methods in this module are mixed in as class methods of a Class object
module StaticHelpers
  alias old_respond_to? respond_to?

  def help(method_name = nil)
    if method_name == nil
      Help::get_type_help(clr_type)
    else
      Help::get_member_help(clr_type, method_name)
    end
    nil
  end
  
  def respond_to?(method)
    result = old_respond_to?(method)
    begin
      result = import(method)
    rescue
      return false
    end
    true
  end
  
  def list_methods(with_params = false)
    InstanceHelpers::internal_list_methods(clr_type, with_params)
  end

  def list_interfaces
    InstanceHelpers::internal_list_interfaces(clr_type)
  end

  def list_properties
    InstanceHelpers::internal_list_properties(clr_type)
  end

  def list_events
    InstanceHelpers::internal_list_events(clr_type)
  end

  def list_fields
    InstanceHelpers::internal_list_fields(clr_type)
  end
  
  def clr_type
    get_clr_type(@clr_type)
  end
end
