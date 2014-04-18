# This file contains macros for RbDynamicMethod. Macros are let you compose
# lower-level CIL instructions into more meaningful abstractions. Much of the
# work in this file was inspired by a presentation by Ward Cunningham at OOPSLA
# 2005 where he talked about refactoring assembly language via a CPU runtime
# that he created.

module RbDynamicMethodMacros
  def ldc_i4_Qnil
    ldc_i4_4
  end

  def ldc_Qtrue
    ldc_i4_2
  end
  
  def ldc_Qfalse
    ldc_i4_0  
  end
  
  def ld_argc
    ldarg_0
  end

  def ld_args
    ldarg_1
  end
  
  def ld_self
    ldarg_2
  end

  def ret_string(value)
    ldstr        value
    call         'static Marshal::ToRubyString(String)'
    ret
  end
  
  def ret_objref(local_variable_name)
    ld_self
    ldloc_s      local_variable_name
    call         'static Marshal::AssignToClassInstance(VALUE, Object)'
    ret
  end

  def ret_valuetype(local_variable_name, type)
    ld_self
    ldc_i4_s     16
    add
    ldind_i4
    ldloca_s     local_variable_name
    cpobj        type
    ldc_i4_Qnil
    ret
  end

  @@type_dictionary = {
    'System.Boolean' => 'Boolean',
    'Boolean'        => 'Boolean',
    'System.Int64'   => 'Int64',
    'Int64'          => 'Int64',
    'System.UInt64'  => 'UInt64',
    'UInt64'         => 'UInt64',
    'System.Int32'   => 'Int32',
    'Int32'          => 'Int32',
    'System.UInt32'  => 'UInt32',
    'UInt32'         => 'UInt32',
    'System.Int16'   => 'Int16',
    'Int16'          => 'Int16',
    'System.UInt16'  => 'UInt16',
    'UInt16'         => 'UInt16',
    'System.SByte'   => 'SByte',
    'SByte'          => 'SByte',
    'System.Byte'    => 'Byte',
    'Byte'           => 'Byte',
    'System.Double'  => 'Double',
    'Double'         => 'Double',
    'System.Single'  => 'Single',
    'Single'         => 'Single',
    'System.String'  => 'ClrString',
    'String'         => 'ClrString',
    'System.Void'    => 'Void',
    'Void'           => 'Void',
  }

  def marshal2clr(type)
    type_name = @@type_dictionary[type]
    if type_name == 'Void'
      pop
    elsif type_name == nil
      if is_value_type?(type)
        if is_enum?(type)
          call 'static Marshal::ToEnum(VALUE)'
        else
          ldc_i4_s   16
          add
          ldind_i4
          ldobj      type
        end
      else
        # do a runtime type check to see if we need to box
        # need local to store / retrieve variable
        call 'static Marshal::ToObject(VALUE)'
        
      end
    else
      call "static Marshal::To#{type_name}(VALUE)"
    end
  end

  def marshal2rb(type, i = 0)
    case type
    when 'System.Void':     call  'static Marshal::ToRubyNil()'
    when 'System.Boolean':  call  'static Marshal::ToRubyBoolean(Boolean)'
    when 'System.Int64':    call  'static Marshal::ToRubyNumber(Int64)'
    when 'System.Int32':    call  'static Marshal::ToRubyNumber(Int32)'
    when 'System.Int16':    call  'static Marshal::ToRubyNumber(Int16)'
    when 'System.SByte':    call  'static Marshal::ToRubyNumber(SByte)'
    when 'System.UInt64':   call  'static Marshal::ToRubyNumber(UInt64)'
    when 'System.UInt32':   call  'static Marshal::ToRubyNumber(UInt32)'
    when 'System.UInt16':   call  'static Marshal::ToRubyNumber(UInt16)'
    when 'System.Byte':     call  'static Marshal::ToRubyNumber(Byte)'
    when 'System.Double':   call  'static Marshal::ToRubyNumber(Double)'
    when 'System.Single':   call  'static Marshal::ToRubyNumber(Single)'
    when 'System.String':   call  'static Marshal::ToRubyString(String)'
    when 'System.Decimal':  call  'static Marshal::ToRubyNumber(Decimal)'
    else
      if is_value_type?(type)
        if is_enum?(type)
          enum_value = "enum_value#{i}".to_sym

          declare    'Int32', enum_value

          stloc_s    enum_value
          ldstr      type
          ldloc_s    enum_value
          call       'static Marshal::ToRubyEnum(String, Int32)'
        else
          return_value = "return_value#{i}".to_sym
          ruby_object  = "ruby_object#{i}".to_sym

          declare    type,    return_value
          declare    'Void*', ruby_object
          
          stloc_s    return_value
          sizeof     type
          call_ruby  'ruby_xmalloc'
          stloc_s    ruby_object
          ldloc_s    ruby_object
          ldloca_s   return_value
          cpobj      type
          ldstr      type
          ldloc_s    ruby_object
          call       'static Marshal::ToRubyObjectByValue(String, Void*)'
        end
      else
        # This branch is taken for boxed value types as well
        call       'static Marshal::ToRubyObject(Object)'
      end
    end
  end

  def throw_clr(message)
    ldstr    message
    newobj   'System.Exception(String)'
    throw_ex
  end

  def debug(message)
    ldstr    message
    call     'static Console::WriteLine(String)'
  end
end
