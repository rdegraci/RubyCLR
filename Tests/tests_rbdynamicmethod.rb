require 'rubyclr'
require 'test/unit'

reference_file 'TestTargets.dll'

class TokenParser < Test::Unit::TestCase
  def test_static_method_no_params
    assert_equal [true, 'System.Console', 'WriteLine', nil, ''], RbTokenParser::parse_method_ref('static System.Console::WriteLine()')
  end

  def test_instance_method_no_params
    assert_equal [false, 'System.Console', 'WriteLine', nil, ''], RbTokenParser::parse_method_ref('System.Console::WriteLine()')
  end

  def test_instance_get_property
    assert_equal [false, 'OpCode', 'get_Value', nil, ''], RbTokenParser::parse_method_ref('OpCode::get_Value()')
  end

  def test_invalid_instance_method
    assert_equal false, RbTokenParser::is_method_ref?('ArrayList::Add')
    assert_raises RuntimeError do
      RbTokenParser::parse_method_ref('ArrayList::Add')
    end
  end

  def test_valid_field_ref
    assert_equal [true, 'OpCodes', 'Add'], RbTokenParser::parse_field_ref('static OpCodes::Add')
  end

  def test_invalid_field_ref
    assert_equal false, RbTokenParser::is_field_ref?('static OpCodes::Add()')
    assert_raises RuntimeError do
      RbTokenParser::parse_field_ref('static OpCodes::Add()')
    end
  end

  def test_invalid_type_ref
    assert_equal false, RbTokenParser::is_type_ref?('OpCodes::Add()')
#    assert_raises RuntimeError do
#      RbTokenParser::parse_type_ref('OpCodes::Add()')
#    end
  end
end

class RubyMethodTests < Test::Unit::TestCase
  def test_do_nothing
    create_ruby_module_function(RbDynamicMethod, 'do_nothing') do
      ldc_i4_4
      ret
    end
    assert_equal nil, do_nothing
  end

  def test_do_nothing_2
    create_ruby_module_function(RbDynamicMethod, 'return_nil') do
      call   'static Marshal::ToRubyNil()'
      ret
    end
    assert_equal nil, return_nil
  end

  def test_say_hello
    create_ruby_module_function(RbDynamicMethod, 'say_hello') do
      ldstr    'Hello, World, int = {0}, float = {1}'
      ldc_i4_1
      box      'Int32'
      ldc_r8   3.14159
      box      'Double'
      call     'static String::Format(String,Object,Object)'
      call     'static Marshal::ToRubyString(String)'
      ret
    end
    # TODO: need to localize this string in Ruby so that it doesn't break
    # when running the tests on non-english locales
    assert_equal 'Hello, World, int = 1, float = 3.14159', say_hello
  end

  def test_forward_branch
    create_ruby_module_function(RbDynamicMethod, 'forward_branch') do
      ldc_i4_0
      br_s     :end_of_method
      ldc_i4_1
      label    :end_of_method
      call     'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 0, forward_branch
  end

  def test_backward_branch
    create_ruby_module_function(RbDynamicMethod, 'backward_branch') do
      undef sub # todo - instance_eval this
      declare   'Int32', :i
      ldc_i4_s  10
      stloc_s   :i
      br_s      :end_of_loop
      label     :loop
      ldloc_s   :i
      ldc_i4_1
      sub
      stloc_s   :i
      label     :end_of_loop
      ldloc_s   :i
      ldc_i4_0
      bgt_s     :loop
      ldloc_s   :i
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 0, backward_branch
  end

  def test_floating_point
    create_ruby_module_function(RbDynamicMethod, 'floating_point') do
      ldc_r8  3.14159
      call    'static Marshal::ToRubyNumber(Double)'
      ret
    end
    assert_equal 3.14159, floating_point
  end
  
  def test_raise_exception_when_defining_cil_outside_create_method_block
    assert_raises RuntimeError do
      ldstr 'bad'
    end
  end

  def test_declare_local_offset_reference
    create_ruby_module_function(RbDynamicMethod, 'declare_local_offset_reference') do
      declare   'Int32', :count
      ldc_i4    42
      stloc_0
      ldloc_0
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 42, declare_local_offset_reference
  end

  def test_declare_local_explicit_offset_reference
    create_ruby_module_function(RbDynamicMethod, 'declare_local_explicit_offset_reference') do
      declare   'Int32', :count
      ldc_i4    42
      stloc     0
      ldloc     0
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 42, declare_local_explicit_offset_reference
  end

  def test_declare_local_name_reference
    create_ruby_module_function(RbDynamicMethod, 'declare_local_name_reference') do
      declare   'Int32', :count
      ldc_i4    42
      stloc     :count
      ldloc     :count
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 42, declare_local_name_reference
  end

  def test_static_field_reference
    create_ruby_module_function(RbDynamicMethod, 'static_field_reference') do
      include   'System.Reflection.Emit'
      declare   'OpCode', :op_code
      ldsfld    'static OpCodes::Add'
      stloc_0
      ldloca_s  :op_code
      call      'OpCode::get_Value()'
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 88, static_field_reference
  end

  def test_default_ctor_reference
    create_ruby_module_function(RbDynamicMethod, 'default_ctor_reference') do
      include   'System.Collections'
      newobj    'ArrayList()'
      callvirt  'ArrayList::get_Count()'
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 0, default_ctor_reference
  end

  def test_single_argument_ctor_reference
    create_ruby_module_function(RbDynamicMethod, 'single_argument_ctor_reference') do
      include   'System.Collections'
      declare   'ArrayList', :a
      ldc_i4_4  
      newobj    'ArrayList(Int32)'
      stloc     :a
      ldloc     :a
      ldc_i4_0
      box       'Int32'
      call      'ArrayList::Add(Object)'
      pop
      ldloc     :a
      ldc_i4_1
      box       'Int32'
      call      'ArrayList::Add(Object)'
      pop
      ldloc     :a
      ldc_i4_2
      box       'Int32'
      call      'ArrayList::Add(Object)'
      pop
      ldloc     :a
      ldc_i4_3
      box       'Int32'
      call      'ArrayList::Add(Object)'
      pop
      ldloc     :a
      callvirt  'ArrayList::get_Count()'
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 4, single_argument_ctor_reference
  end

  def test_convert_clr_exception
    create_ruby_module_function(RbDynamicMethod, 'convert_clr_exception') do
      try
        ldstr    'error'
        newobj   'Exception(String)'
        throw_ex
      catch_ex   'Exception'
        call     'static Marshal::ToRubyException(Exception)'
      end_try
      ldc_i4_4
      ret
    end
    assert_raises RuntimeError do
      convert_clr_exception
    end
  end
end

class SafeRubyMethodTests < Test::Unit::TestCase
  def test_catch_clr_exception
    create_safe_ruby_module_function(RbDynamicMethod, 'catch_clr_exception') do
      ldstr    'error'
      newobj   'Exception(String)'
      throw_ex
      ldc_i4_4
      ret
    end
    assert_raises RuntimeError do
      catch_clr_exception
    end
  end
end

class BindInstanceMethodToClassTests < Test::Unit::TestCase
  class TestClass
  end

  def test_create_instance_method
    create_ruby_instance_method(TestClass, 'instance_method') do
      ldstr   'hello, world'
      call    'static Marshal::ToRubyString(String)'
      ret
    end
    assert_equal 'hello, world', TestClass.new.instance_method    
  end

  def test_create_instance_method_on_preexisting_object
    obj = TestClass.new
    
    create_ruby_instance_method(TestClass, 'instance_method') do
      ldstr   'hello, world'
      call    'static Marshal::ToRubyString(String)'
      ret
    end
    assert_equal 'hello, world', obj.instance_method
  end
end

class BindSingletonMethodToClassTests < Test::Unit::TestCase
  class TestClass
  end

  def test_add_singleton_method
    create_ruby_singleton_method(TestClass, 'singleton_method') do
      ldc_i4  42
      call    'static Marshal::ToRubyString(Int32)'
      ret
    end
    assert_equal '42', TestClass.singleton_method
  end

  def test_add_safe_singleton_method_with_type_mismatch_error
    create_safe_ruby_singleton_method(TestClass, 'singleton_method') do
      ldc_i4  42 #int
      call    'static Marshal::ToRubyString(String)' #string!
      ret
    end
    assert_raises RuntimeError do
      TestClass.singleton_method
    end
  end
end

class MarshalParametersToRubyTests < Test::Unit::TestCase
  class Calc
  end

  def test_add
    create_ruby_instance_method(Calc, 'add') do
      declare  'Int32', :x
      declare  'Int32', :y
      ldarg_1
      ldind_i4
      call     'static Marshal::ToInt32(VALUE)'
      stloc_s  :x
      ldarg_1
      ldc_i4_4
      add
      ldind_i4
      call     'static Marshal::ToInt32(VALUE)'
      stloc_s  :y
      ldloc_s  :x
      ldloc_s  :y
      add
      call     'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 7, Calc.new.add(3, 4)
  end

  def test_float_multiply
    create_ruby_instance_method(Calc, 'multiply') do
      declare  'Double', :x
      declare  'Double', :y
      ldarg_1
      ldind_i4
      call     'static Marshal::ToDouble(VALUE)'
      stloc_s  :x
      ldarg_1
      ldc_i4_4
      add
      ldind_i4
      call     'static Marshal::ToDouble(VALUE)'
      stloc_s  :y
      ldloc_s  :x
      ldloc_s  :y
      mul
      call     'static Marshal::ToRubyNumber(Double)'
      ret
    end
    assert_equal 13.2, Calc.new.multiply(3.3, 4)
  end
end

class BooleanMarshalerTests < Test::Unit::TestCase
  def test_true
    create_ruby_module_function(RbDynamicMethod, 'return_true') do
      ldc_i4_1
      call     'static Marshal::ToRubyBoolean(Boolean)'
      ret
    end
    assert_equal true, return_true
  end

  def test_false
    create_ruby_module_function(RbDynamicMethod, 'return_false') do
      ldc_i4_0
      call     'static Marshal::ToRubyBoolean(Boolean)'
      ret
    end
    assert_equal false, return_false
  end
end

class IntegerMarshalerTests < Test::Unit::TestCase
  def test_int64_upper_limit
    create_ruby_module_function(RbDynamicMethod, 'int64') do
      ldc_i8   2 ** 63 - 1
      call     'static Marshal::ToRubyNumber(Int64)'
      ret
    end
    assert_equal 2 ** 63 - 1, int64
  end

  def test_int64_lower_limit
    create_ruby_module_function(RbDynamicMethod, 'int64') do
      ldc_i8(  -(2 ** 63))
      call     'static Marshal::ToRubyNumber(Int64)'
      ret
    end
    assert_equal(-(2 ** 63), int64)
  end

  def test_int64_out_of_upper_bounds
    assert_raises RangeError do
      create_ruby_module_function(RbDynamicMethod, 'int64') do
        ldc_i4   2 ** 63
      end
    end
  end

  def test_int64_out_of_lower_bounds
    assert_raises RangeError do
      create_ruby_module_function(RbDynamicMethod, 'int64') do
        ldc_i4(  -(2 ** 63) - 1)
      end
    end
  end

  def test_int32_upper_limit
    create_ruby_module_function(RbDynamicMethod, 'int32') do
      ldc_i4   2 ** 31 - 1
      call     'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 2 ** 31 - 1, int32
  end

  def test_int32_lower_limit
    create_ruby_module_function(RbDynamicMethod, 'int32') do
      ldc_i4(  -(2 ** 31))
      call     'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal(-(2 ** 31), int32)
  end

  def test_int32_out_of_upper_bounds
    assert_raises RangeError do
      create_ruby_module_function(RbDynamicMethod, 'int32') do
        ldc_i4   2 ** 31
      end
    end
  end

  def test_int32_out_of_lower_bounds
    assert_raises RangeError do
      create_ruby_module_function(RbDynamicMethod, 'int32') do
        ldc_i4(  -(2 ** 31) - 1)
      end
    end
  end
end

class StringMarshalerTests < Test::Unit::TestCase
  def test_int64_to_string
    create_ruby_module_function(RbDynamicMethod, 'int64_to_string') do
      ldc_i8   2 ** 63 - 1
      call     'static Marshal::ToRubyString(Int64)'
      ret
    end
    assert_equal((2 ** 63 - 1).to_s, int64_to_string)
  end

  def test_int32_to_string
    create_ruby_module_function(RbDynamicMethod, 'int32_to_string') do
      ldc_i4   2 ** 31 - 1
      call     'static Marshal::ToRubyString(Int32)'
      ret
    end
    assert_equal((2 ** 31 - 1).to_s, int32_to_string)
  end

  def test_bool_to_string
    create_ruby_module_function(RbDynamicMethod, 'bool_to_string') do
      ldc_i4_1
      call     'static Marshal::ToRubyString(Boolean)'
      ret
    end
    assert_equal 'True', bool_to_string
  end    
end

class SwitchTests < Test::Unit::TestCase
  def test_switch_statement
    create_ruby_module_function(RbDynamicMethod, 'switch_statement') do
      declare   'Int32', :flag
      declare   'Int32', :result
      ldc_i4_2
      stloc_s   :flag
      ldloc_s   :flag
      switch    [:one, :two, :three]
      br_s      :default
      label     :one
      ldc_i4_s  42
      stloc_s   :result
      br_s      :end
      label     :two
      ldc_i4_0
      stloc_s   :result
      br_s      :end
      label     :three
      ldc_i4_m1
      stloc_s   :result
      br_s      :end
      label     :default
      ldc_i4_s  10
      stloc_s   :result
      label     :end
      ldloc_s   :result
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal(-1, switch_statement)
  end
end

class GenericTypeTests < Test::Unit::TestCase
  def test_create_list_string
    create_ruby_module_function(RbDynamicMethod, 'create_list_string') do
      include   'System.Collections.Generic'
      declare   'List<String>', :list
      newobj    'List<String>()'
      stloc_s   :list
      ldloc_s   :list
      ldstr     'one'
      callvirt  'List<String>::Add(String)'
      ldloc_s   :list
      ldstr     'two'
      callvirt  'List<String>::Add(String)'
      ldstr     '{0}, {1}'
      ldloc_s   :list
      ldc_i4_0
      callvirt  'List<String>::get_Item(Int32)'
      ldloc_s   :list
      ldc_i4_1
      callvirt  'List<String>::get_Item(Int32)'
      call      'static String::Format(String,Object,Object)'
      call      'static Marshal::ToRubyString(String)'
      ret
    end
    assert_equal 'one, two', create_list_string
  end

  def test_create_list_list_string
    create_ruby_module_function(RbDynamicMethod, 'create_list_list_string') do
      include   'System.Collections.Generic'
      declare   'List<String>', :inner_list
      declare   'List<List<String>>', :outer_list
      newobj    'List<List<String>>()'
      stloc_s   :outer_list
      newobj    'List<String>()'
      stloc_s   :inner_list
      ldloc_s   :inner_list
      ldstr     'one'
      callvirt  'List<String>::Add(String)'
      ldloc_s   :inner_list
      ldstr     'two'
      callvirt  'List<String>::Add(String)'
      ldloc_s   :outer_list
      ldloc_s   :inner_list
      callvirt  'List<List<String>>::Add(List<String>)'
      ldstr     '{0}, {1}'
      ldloc_s   :outer_list
      ldc_i4_0
      callvirt  'List<List<String>>::get_Item(Int32)'
      ldc_i4_0
      callvirt  'List<String>::get_Item(Int32)'
      ldloc_s   :outer_list
      ldc_i4_0
      callvirt  'List<List<String>>::get_Item(Int32)'
      ldc_i4_1
      callvirt  'List<String>::get_Item(Int32)'
      call      'static String::Format(String,Object,Object)'
      call      'static Marshal::ToRubyString(String)'
      ret
    end
    assert_equal 'one, two', create_list_list_string
  end
end

class DynamicMethodArrayTests < Test::Unit::TestCase
  def test_get_managed_array
    create_ruby_module_function(RbDynamicMethod, 'get_managed_array') do
      declare     'Int32[]', :a
      call        'static RubyClr.Tests.MarshalerHelper::StaticGetOneDimensionalArray()'
      stloc_s     :a
      ldloc_s     :a
      ldc_i4_0
      ldelem_i4
      call        'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 0, get_managed_array
  end

  def test_two_dimensional_array
    create_ruby_module_function(RbDynamicMethod, 'two_dimensional_array') do
      declare     'Int32[,]', :a
      call        'static RubyClr.Tests.MarshalerHelper::StaticGetTwoDimensionalArray()'
      stloc       :a
      ldloc       :a
      ldc_i4_0
      ldc_i4_0
      call        'Int32[,]::Get(Int32,Int32)'
      call        'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 0, two_dimensional_array
  end
end

class GenericMethodTests < Test::Unit::TestCase
  def test_call_generic_min_method
    create_ruby_module_function(RbDynamicMethod, 'call_generic_min_method') do
      ldc_i4_3
      ldc_i4_2
      call      'static RubyClr.Tests.GenericMethodTests::Min<Int32>(Int32, Int32)'
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 2, call_generic_min_method
  end

  def test_call_generic_three_arg_min_method
    create_ruby_module_function(RbDynamicMethod, 'call_generic_three_arg_min_method') do
      ldc_i4_7
      ldc_i4_3
      ldc_i4_5
      call      'static RubyClr.Tests.GenericMethodTests::Min<Int32>(Int32, Int32, Int32)'
      call      'static Marshal::ToRubyNumber(Int32)'
      ret
    end
    assert_equal 3, call_generic_three_arg_min_method
  end
    
  def test_call_generic_double_three_arg_min_method
    create_ruby_module_function(RbDynamicMethod, 'call_generic_double_three_arg_min_method') do
      ldc_r8    44.25
      ldc_r8    6.25
      ldc_r8    1.14
      call      'static RubyClr.Tests.GenericMethodTests::Min<Double>(Double, Double, Double)'
      call      'static Marshal::ToRubyNumber(Double)'
      ret
    end
    assert_equal 1.14, call_generic_double_three_arg_min_method
  end
    
  def test_call_generic_double_min_method
    create_ruby_module_function(RbDynamicMethod, 'call_generic_double_min_method') do
      ldc_r8    4.77
      ldc_r8    1.23
      call      'static RubyClr.Tests.GenericMethodTests::Min<Double>(Double, Double)'
      call      'static Marshal::ToRubyNumber(Double)'
      ret
    end
    assert_equal 1.23, call_generic_double_min_method
  end

  def test_call_ambiguous_generic_method
    assert_raises ArgumentError do
      create_ruby_module_function(RbDynamicMethod, 'call_ambiguous_generic_method') do
        ldc_i4_3
        ldc_i4_1
        ldc_i4_5
        call      'static RubyClr.Tests.GenericMethodTests::Min<Int16>(Int16, Int16, Int16)'
        call      'static Marshal::ToRubyNumber(Int16)'
        ret
      end
    end
  end
end

class MacroTests < Test::Unit::TestCase
  def test_call_null_macro
    create_ruby_module_function(RbDynamicMethod, 'call_null_macro') do
      ldc_i4_Qnil
      ret
    end
    assert_equal nil, call_null_macro
  end

  def test_call_return_hello_macro
    create_ruby_module_function(RbDynamicMethod, 'call_return_hello_macro') do
      ret_string 'hello, world'
    end
    assert_equal 'hello, world', call_return_hello_macro
  end
end
