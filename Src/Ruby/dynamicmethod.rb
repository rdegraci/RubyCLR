# This file contains the core functionality of the RbDynamicMethod library which
# lets you create CLR DynamicMethods on the fly from Ruby. It is used
# extensively by the RubyCLR library, and it in turn uses methods from the C++
# Runtime library. Code in this library must never make up-calls into RubyCLR.

require 'opcodes'
require 'macros'

module RbTokenParser
  @@method_ref_re = /^(static )?(.*)::([\w_]+)([\[\<](.*)[\]\>])?\((.*)\)$/
  @@field_ref_re  = /^(static )?(.*)::([\w_]+)$/
  @@ctor_ref_re   = /^(.*)\((.*)\)$/
  @@type_ref_re   = /^([\w_\.\+]*)(\`[\d]+[\<\[](.*)[\>|\]])?$/

  def self.is_method_ref?(sig)
    @@method_ref_re.match(sig) != nil
  end

  @@type_name_map = { 
    'System.Reflection.RtFieldInfo'         => 'System.Reflection.FieldInfo',
    'System.RuntimeType'                    => 'System.Type',
    'System.Reflection.RuntimePropertyInfo' => 'System.Reflection.PropertyInfo',
    'System.Reflection.RuntimeEventInfo'    => 'System.Reflection.EventInfo',
    'System.Reflection.RuntimeMethodInfo'   => 'System.Reflection.MethodInfo' }
  
  def self.map_type_name(type_name)
    @@type_name_map.has_key?(type_name) ? @@type_name_map[type_name] : type_name
  end

  def self.parse_method_or_ctor_ref(sig)
    m = @@method_ref_re.match(sig)
    if m == nil
      m = @@ctor_ref_re.match(sig)
      raise "Invalid method or constructor signature #{sig}" if m == nil
      type_name, parameters = m[1], m[2]
      return 'ctor', type_name, parameters
    else
      is_static = m[1] == 'static '
      type_name, method_name, method_types, parameters = m[2], m[3], m[5], m[6]
      return 'method', is_static, map_type_name(type_name), method_name, method_types, parameters
    end
  end
  
  def self.parse_method_ref(sig)
    m = @@method_ref_re.match(sig)
    raise "Invalid method signature #{sig}" if m == nil
    is_static = m[1] == 'static '
    type_name, method_name, method_types, parameters = m[2], m[3], m[5], m[6]
    return is_static, map_type_name(type_name), method_name, method_types, parameters
  end

  def self.is_field_ref?(sig)
    @@field_ref_re.match(sig) != nil
  end

  def self.parse_field_ref(sig)
    m = @@field_ref_re.match(sig)
    raise "Invalid field signature #{sig}" if m == nil
    is_static = m[1] == 'static '
    type_name, field_name = m[2], m[3]
    return is_static, map_type_name(type_name), field_name
  end

  def self.parse_ctor_ref(sig)
    m = @@ctor_ref_re.match(sig)
    raise "Invalid constructor signature #{sig}" if m == nil
    type_name, parameters = m[1], m[2]
    return map_type_name(type_name), parameters
  end

  def self.is_type_ref?(sig)
    @@type_ref_re.match(sig) != nil
  end

  def self.parse_type_ref(sig)
    return map_type_name(sig)
    #m = @@type_ref_re.match(sig)
    #raise "Invalid type signature: #{sig}" if m == nil
    #type_name, types = m[1], m[3]
    #if types == nil
    #  map_type_name(type_name)
    #else
    #  type_list = types.split(',').collect { |t| map_type_name(t.strip) }
    #  "#{type_name}`#{type_list.length}[#{type_list.join(',')}]"
    #end
  end
end

module RbDynamicMethod
private
  @@mixins  = [RbDynamicMethod, RbDynamicMethodMacros]

  def create_generator(method)
    create_generator_object(get_cil_generator(method), nil, '')
  end

  def create_ruby_varargs_method
    method = create_dynamic_method('', 'System.UInt32', 'System.Int32,System.UInt32*,System.UInt32')
    object = RbDynamicMethod::mixin(create_generator(method))
    return method, object
  end

  def core_create_ruby_method(type, name, method_type)
    method, object = create_ruby_varargs_method
    yield object
    case method_type
    when :module_function:  define_ruby_module_function(type, method, name)
    when :instance_method:  define_ruby_method(type, method, name)
    when :singleton_method: define_ruby_singleton_method(type, method, name)
    end
  end

  def core_create_raw_ruby_method(type, name, method_type, &b)
    core_create_ruby_method(type, name, method_type) { |g| g.instance_eval(&b) }
  end

  def core_create_safe_ruby_method(type, name, method_type, &b)
    core_create_ruby_method(type, name, method_type) do |g|
      g.instance_eval('try')
      g.instance_eval(&b)
      g.instance_eval("catch_ex 'Exception'")
      g.instance_eval("call 'static Marshal::ToRubyException(Exception)'")
      g.instance_eval('end_try')
      # TODO: need to modify this since methods can easily have return values
      # and I'm returning a Ruby nil here which works for delegates but not
      # for some delegates that could easily have return values.
      g.instance_eval('ldc_i4_4')
      g.instance_eval('ret')
    end
  end
  
public
  def create_ruby_module_function(module_name, name, &b)
    core_create_raw_ruby_method(module_name, name, :module_function, &b)
  end

  def create_safe_ruby_module_function(module_name, name, &b)
    core_create_safe_ruby_method(module_name, name, :module_function, &b)
  end

  def create_ruby_instance_method(class_or_module, name, &b)
    core_create_raw_ruby_method(class_or_module, name, :instance_method, &b)
  end

  def create_safe_ruby_instance_method(class_or_module, name, &b)
    core_create_safe_ruby_method(class_or_module, name, :instance_method, &b)
  end

  def create_ruby_singleton_method(class_or_module, name, &b)
    core_create_raw_ruby_method(class_or_module, name, :singleton_method, &b)
  end

  def create_safe_ruby_singleton_method(class_or_module, name, &b)
    core_create_safe_ruby_method(class_or_module, name, :singleton_method, &b)
  end

  def create_event_shim(klass, object, event_name, is_static, &b)
    method    = create_event_dynamic_method(object, event_name, is_static)
    generator = RbDynamicMethod::mixin(create_generator(method))
    generator.instance_eval(&b)
    klass.instance_variable_get('@event_refs') << b
    define_event_method(object, method, event_name, is_static)
  end

  def self.create_method_interface(generator, &b)
    RbDynamicMethod::mixin(generator)
    generator.instance_eval(&b)
  end
  
  def include(namespaces)
    append_namespaces(namespaces.gsub(' ', ''))
  end

  def ldtoken(sig)
    emit_method_ref('ldtoken', *RbTokenParser::parse_method_ref(sig)) if RbTokenParser::is_method_ref?(sig)
    emit_field_ref('ldtoken', *RbTokenParser::parse_field_ref(sig)) if RbTokenParser::is_field_ref?(sig)
    emit_type_ref('ldtoken', *RbTokenParser::parse_type_ref(sig)) if RbTokenParser::is_type_ref?(sig)
  end

  alias default_method_missing method_missing

  def method_missing(name, *parameters)
    op_code = name.to_s
    if @@op_codes.has_key?(op_code)
      raise 'CIL opcodes only valid within a create_method block' unless self.instance_of?(Generator)
      type = @@op_codes[op_code]
      case type
      when 's':   emit_string(op_code, parameters[0])
      when 'm':   emit_method_ref(op_code, *RbTokenParser::parse_method_ref(parameters[0]))
      # TODO: hack alert: not sure if i'm going to keep this 
      when 'mc':
        params = *RbTokenParser::parse_method_or_ctor_ref(parameters[0])
        if params[0] == 'ctor'
          emit_ctor_ref(op_code, *params[1..10])
        else
          emit_method_ref(op_code, *params[1..10])
        end
      when 'c':   emit_ctor_ref(op_code,  *RbTokenParser::parse_ctor_ref(parameters[0]))
      when 't':   emit_type_ref(op_code,  *RbTokenParser::parse_type_ref(parameters[0]))
      when 'f':   emit_field_ref(op_code, *RbTokenParser::parse_field_ref(parameters[0]))
      when 'l':
          if parameters[0].instance_of?(Symbol)
            emit_label(op_code, parameters[0].to_s)
          else
            raise 'Label references must be :symbols'
          end
      when 'i64': emit_int64(op_code, parameters[0])
      when 'i32': emit_int32(op_code, parameters[0])
      when 'i16': emit_int16(op_code, parameters[0])
      when 'i8':  emit_int8(op_code, parameters[0])
      when 'u8':  emit_uint8(op_code, parameters[0])
      when 'd':   emit_double(op_code, parameters[0])
      when 'v':
          if parameters[0].instance_of?(Fixnum)
            emit_int32(op_code, parameters[0])
          elsif parameters[0].instance_of?(Symbol)
            emit_local_variable_reference(op_code, parameters[0].to_s)
          else
            raise 'Variable references must be either by index or by :symbol'
          end
      when 'sw':  emit_switch_statement(parameters[0])
      when nil: emit(op_code)
      end
    else
      default_method_missing(name, *parameters)
    end
  end
  
  def self.mixin(generator)
    generator.extend(*@@mixins)
  end
  
  def self.register_macro_module(macro_module)
    @@mixins << macro_module
  end
end
