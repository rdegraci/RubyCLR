require 'test/unit'
include Test::Unit

require_gem 'activerecord'

require 'rubyclr'

reference 'System.Windows.Forms'
reference 'System.Drawing'
reference 'System.Data'
reference 'System.Xml'
reference 'System'
reference_file 'TestTargets.dll'

include System
include System::Collections
include System::Collections::Generic
include System::Drawing
include RubyClr::Tests

class ConstructorTests < TestCase
  def test_default_ctor
    assert_equal 'System.Collections.ArrayList', ArrayList.new.clr_type.full_name
  end

  def test_single_arg_ctor
    assert_equal 'System.Collections.ArrayList', ArrayList.new(42).clr_type.full_name
  end

  def test_fail_multi_arg_ctor
    assert_raises RuntimeError do
      ArrayList.new(42, 42, 42) 
    end
  end

  def test_stack_default_ctor
    # Fully qualified type name because there is a System::Generic::Collections::Stack
    assert_equal 'System.Collections.Stack', System::Collections::Stack.new.clr_type.full_name
  end
end

class MarshalerTests < TestCase
  def test_marshal_integers
    a = ArrayList.new
    a.add(0)
    a.add(-1)
    a.add(2^32)
    a.add(2^63)
    assert_equal 0, a.get_Item(0)
    assert_equal(-1, a.get_Item(1))
    assert_equal 2^32, a.get_Item(2)
    assert_equal 2^63, a.get_Item(3)
  end

  def test_marshal_floating_point
    a = ArrayList.new
    a.add(3.1415926)
    a.add(2.18281828)
    assert_equal 3.1415926, a.get_Item(0)
    assert_equal 2.18281828, a.get_Item(1)
  end

  def test_marshal_boolean
    a = ArrayList.new
    a.add(true)
    a.add(false)
    assert_equal true, a.get_Item(0)
    assert_equal false, a.get_Item(1)
  end

  def test_marshal_strings
    a = ArrayList.new
    a.add('John')
    a.add('Jacob')
    assert_equal 'John', a.get_Item(0)
    assert_equal 'Jacob', a.get_Item(1)
  end

  def test_marshal_decimals
    assert_equal 3.14159, MarshalerHelper.get_decimal.to_f
  end
  
  def test_marshal_objref
    p = RubyClr::Tests::MarshalerHelper.new.get_person
    assert_equal 'John', p.name
  end
end

class MethodTests < TestCase
  def test_count_method
    assert_equal 0, ArrayList.new.get_Count
  end

  def test_add
    a = ArrayList.new
    assert_equal 0, a.Add(42)
    assert_equal 1, a.Add('Two')
    assert_equal 2, a.get_Count
    assert_equal 42, a.get_Item(0)
    assert_equal 'Two', a.get_Item(1)
  end

  def test_missing_method
    assert_raises RuntimeError do
      ArrayList.new.BillyBob
    end
  end
end

class PropertyTests < TestCase
  def test_count_method
    assert_equal 0, ArrayList.new.get_Count
  end

  def test_count_property
    assert_equal 0, ArrayList.new.Count
  end

  def test_get_indexer
    a = ArrayList.new
    a.Add(42)
    a.Add('John')
    assert_equal 42, a[0]
    assert_equal 'John', a[1]
  end

  def test_set_indexer
    a = ArrayList.new
    a.Add(42)
    assert_equal 42, a[0]
    a[0] = 'John'
    assert_equal 'John', a[0]
  end

  def test_property_overload_resolution
    o = RubyClr::Tests::PropertyOverloads.new
    o[4] = 42
    o['5'] = 43
    assert_equal 42, o[4]
    assert_equal 43, o[5]
    assert_equal 42, o['4']
    assert_equal 43, o['5']
  end

  def test_static_property
    assert_equal 0, RubyClr::Tests::PropertyOverloads.StaticProperty
    RubyClr::Tests::PropertyOverloads.StaticProperty = 42
    assert_equal 42, RubyClr::Tests::PropertyOverloads.StaticProperty
  end

  def ztest_static_non_default_overloaded_property # not available for now
    assert_raises RuntimeError do
      RubyClr::Tests::PropertyOverloads.OverloadedProperty[42]
    end
  end
end

class StaticMethodTests < TestCase
  def test_static_method
    a = RubyClr::Tests::MarshalerHelper.StaticGetOneDimensionalArray
    assert_equal 4, a.Length
    assert_equal 1, a.Rank
  end

  def test_static_method_overload_resolution
    p1 = RubyClr::Tests::Person.Create
    p2 = RubyClr::Tests::Person.Create('Mike')
    assert_equal 'John', p1.Name
    assert_equal 'Mike', p2.Name
  end
end

class ArrayTests < TestCase
  def test_one_dimensional_array
    a = RubyClr::Tests::MarshalerHelper.new.GetOneDimensionalArray
    assert_equal 4, a.length
    assert_equal 1, a.rank
    # this returns a value type that is a boxed integer!
    assert_equal 0, a.get_value(0)
    assert_equal 0, a[0]
    assert_equal 1, a[1]
  end

  def test_two_dimensional_array
    a = RubyClr::Tests::MarshalerHelper.StaticGetTwoDimensionalArray
    assert_equal 0, a.get_value(0, 0)
    assert_equal 2, a.rank
    assert_equal 2, a.get_length(0)
    assert_equal 2, a.get_length(1)
    assert_equal 0, a[0, 0]
    assert_equal 1, a[0, 1]
    assert_equal 1, a[1, 0]
    assert_equal 0, a[1, 1]
  end

  def test_three_dimensional_array
    a = RubyClr::Tests::MarshalerHelper.StaticGetThreeDimensionalArray
    assert_equal 3, a.rank
    assert_equal 2, a.get_length(0)
    assert_equal 2, a.get_length(1)
    assert_equal 2, a.get_length(2)
    assert_equal 0, a[0, 0, 0]
    assert_equal 1, a[0, 0, 1]
    assert_equal 0, a[1, 0, 0]
  end
  
  def test_create_array_shadow_class
    a1 = Array.of(Int32)
    a2 = Array.of(Byte,Byte)
    a3 = Array.of(Int32, Int32)
    assert_equal 'System.Int32[]', a1.clr_type.full_name
    assert_equal 'System.Byte[,]', a2.clr_type.full_name
    assert_equal 'System.Int32[,]', a3.clr_type.full_name
  end
  
  def test_create_invalid_array_shadow_class
    assert_raises RuntimeError do
      a = Array.of(Int32, Double)
    end
  end
  
  def test_create_and_use_array
    a = Array.of(Int32).new(10)
    assert 10, a.length
    ArrayTestHelper.AddOne(a)
    0.upto(a.length - 1) { |i| assert_equal 1, a[i] }
  end
  
  def test_convert_array_to_int32
    source = [1, 2, 3]
    dest = source.to_ary_of(Int32)
    assert_equal 3, dest.length
    assert_equal 1, dest[0]
    assert_equal 2, dest[1]
    assert_equal 3, dest[2]
  end
  
  def test_convert_array_to_string
    source = ['hello', 'world', 'three']
    dest = source.to_ary_of(System::String)
    assert_equal 3, dest.length
    assert_equal 'hello', dest[0]
    assert_equal 'world', dest[1]
    assert_equal 'three', dest[2]
  end
  
  # BUGBUG: these types of expected type conversion errors blow up with nasty
  # hard to diagnose error messages. I really need to think about type conversion
  # errors up front to see how this should be handled in the generated shims.
  def ztest_convert_heterogeneous_array
    source = [1, 'hello', 2.5]
    dest = source.to_ary_of(System::String)
    assert_equal 3, dest.length
  end
end

class EventTests < TestCase
  def test_simple_event
    c = RubyClr::Tests::CallbackTests.new('John')
    c.event do |sender, args|
      assert_equal 1, 1
    end
    c.call_me_back
  end

  def test_event_parameter_marshaling
    c = RubyClr::Tests::CallbackTests.new('Mike')
    assert_equal 'Mike', c.name
    c.event do |sender, args|
      assert_equal 'Mike', sender.name
    end
    c.call_me_back
  end

  def test_value_type_parameter_marshaling
    c = RubyClr::Tests::DelegateCalc.new(3, 4)
    c.add_result do |sender, result|
      assert_equal 7, result
    end
    c.add
  end

  def test_static_event
    RubyClr::Tests::DelegateCalc.static_add_result do |sender, result|
      assert_equal 42, result
    end
    RubyClr::Tests::DelegateCalc.static_test
  end
end

class FieldTests < TestCase
  def test_field_read
    m = RubyClr::Tests::MarshalerHelper.new
    assert_equal 'Hello', m.Name
  end

  def test_field_write
    m = RubyClr::Tests::MarshalerHelper.new
    m.Name = 'John'
    assert_equal 'John', m.Name
  end
end

class ValueTypeTests < TestCase
  def test_get_value_type
    p = RubyClr::Tests::MarshalerHelper.GetPoint
    assert_equal 3, p.X
    assert_equal 4, p.Y
    assert_equal 'System.Drawing.Point', p.clr_type.FullName
  end

  def test_call_value_type_instance_method
    p = RubyClr::Tests::MarshalerHelper.GetPoint
    p.Offset(1, 1)
    assert_equal 4, p.X
    assert_equal 5, p.Y
  end

  def test_create_value_type
    p = Point.new(3, 4)
    assert_equal 3, p.X
    assert_equal 4, p.Y
  end

  def test_marshal_value_type_to_clr
    p1 = Point.new(2, 3)
    s1 = Size.new(p1)
    assert_equal s1.Width, p1.X
    assert_equal s1.Height, p1.Y
  end

  def test_point_clone
    p1 = Point.new(3, 4)
    assert_equal 3, p1.X
    assert_equal 4, p1.Y
    p2 = p1.clone
    assert_equal p1.X, p2.X
    assert_equal p1.Y, p2.Y
    p1.X += 1
    assert_equal p1.X, p2.X + 1
  end

  def test_instance_variable_clone
    p1 = Point.new(3, 4)
    p1.instance_variable_set('@name', 'bob')
    p2 = p1.clone
    p1.instance_variable_set('@name', 'mike')

    assert_equal 'bob', p2.instance_variable_get('@name')
    assert_equal 'mike', p1.instance_variable_get('@name')
    assert_equal 3, p2.X
    assert_equal 4, p2.Y
  end
  
  def test_datetime
    
  end
end

include System::Windows::Forms
include System::Xml

class EnumTests < TestCase
  def test_enum
    k = DialogResult::Abort
    assert_equal DialogResult::Abort, k
    assert_equal 'Abort', k.to_s
    assert_equal 3, k.to_i
  end
  
  def test_node_type_enum
    x = XmlNodeType::Element
    assert_equal XmlNodeType::Element, x
    assert_equal 'Element', x.to_s
    assert_equal 1, x.to_i
  end

  def test_bind_results_enum
    assert_equal 0,      BindResult::None
    assert_equal 1,      BindResult::Bool
    assert_equal 0x1000, BindResult::Array
    assert_equal 0x2000, BindResult::Out
    assert_equal 0x4000, BindResult::Ref
  end
  
  # TODO: i get a really nasty error message here with RubyCLR crashing
  # I need to fail gracefully when you attempt to reference a field that
  # is really an enum.
  def test_bind_enum_as_field
#    assert_equal 0, BindResult.None
  end
end

class MethodOverloadTests < TestCase
  def test_overloads
    o = RubyClr::Tests::MethodOverloads.new
    assert_equal 1, o.Method(1, 'x')
    assert_equal 2, o.Method('x', 'x')
  end
end

# This test case catches the nastiest bug in RubyCLR - I had assumed that
# covariance wasn't possible, but it is if the param signatures disambiguate the
# methods. So while you can't have int Add(string) and int Add(int)
#
# you CAN have:
# int Add(string) and string Add(int)
#
# This is used in a few places in the .NET Frameworks, most notably in
# DataColumnCollection.Add()
#
# This bug presented itself initially as a hard crash with a corrupted stack. It
# wasn't until I looked via Reflector that I realized that it was this form of
# covariance that caused the hard crash. This required a major pass through a
# lot of code in RubyCLR, both C++ and Ruby. This assumption was buried in a
# number of places, but in the end I was happy with how little time it took
# (about 30 min) once I had figured out the root cause of the problem.
#
# This goes to show how the best debugger you have is between your ears - had I
# tried to track down the root cause of the stack corruption, I may have found
# this bug eventually, but it would have taken a LONG time since where it
# crashed was in a fairly unrelated place.

class CoVarianceTests < TestCase
  def test_instance_methods
    o = CoVarianceTarget.new
    assert_equal 1, o.Method('1')
    assert_equal '1', o.Method(1)
  end

  def test_static_methods
    assert_equal 1, CoVarianceTarget.StaticMethod('1')
    assert_equal '1', CoVarianceTarget.StaticMethod(1)
  end  
end

# This bug (or missing feature) forced me into a major refactoring that had the
# really nice performance side-effect of eliminating most of the code from a
# class_eval method call that I used to inject instance and static methods into
# the Ruby CLR shadow class. This makes debugging much easier since the line
# numbers actually match up, and the bizarro string stuff that I had to do can
# now be replaced by the much cleaner "text #{expression}" expressions.

class NestedClassTests < TestCase
  def test_nested_class_resolution
    assert_equal 42, ParentClass::NestedClass.Method
  end
  
  def test_nested_nested_class_resolution
    assert_equal 100, ParentClass::NestedClass::MoreNestedClass.Method
  end
end

class SimpleBindTests < TestCase
  def test_bind_string
    assert_equal 'Hello', BindingTestClass.Bind('Hello')
  end

  def test_bind_int
    assert_equal 10, BindingTestClass.Bind(10)
  end

  def test_bind_boolean
    assert_equal false, BindingTestClass.Bind(false) 
  end
end

class InheritedBindTests < TestCase
  def setup
    @b = InheritedBindingSub.new
  end
  
  def test_bind_string
    assert_equal 'Subclass string', @b.Bind('Hi')
  end

  def test_bind_int
    assert_equal 'Subclass int', @b.Bind(10)
  end

  def test_bind_boolean
    assert_equal 'Subclass bool', @b.Bind(true)
  end
end

class DispatchTests < TestCase
  def setup
    @d = Dispatch.new
  end

  def check(expected_value)
    Dispatch.Flag = 0
    yield if block_given?
    assert_equal expected_value, Dispatch.Flag
  end

  def test_enum_overloads
    check(101) { @d.M1(1) }
    check(201) { @d.M1(DispatchHelpers::Color::Red) }
  end

  def test_enum_implicit_conversion_to_integer
    check(111) { @d.M11(1, 1) }
    check(211) { @d.M11(DispatchHelpers::Color::Red, 1) }
    # todo: make these pass!
    # check(111) { @d.M11(1, DispatchHelpers::Color::Red) }
    # check(211) { @d.M11(DispatchHelpers::Color::Red, DispatchHelpers::Color::Red) }
  end

  def test_integer_param_array
    check(102) { @d.M2(1) }
    # todo: overload resolution algorithm with int param array
  end

  def test_simple_overload
    check(103) { @d.M3(1) }
    check(203) { @d.M3(1, 1) }
  end

  def ztest_float_vs_single_overload
    # NOTE: There is no way for me to represent the result of Single.Parse as
    # anything but a double, since I convert it into a Ruby float value when
    # marshaling back to Ruby. Short of annotating the float object, (maybe in
    # the future?) I can't see a way to make that work. Even if I did do this,
    # would it actually be useful to anyone???
    check(205) { @d.M5(Single.Parse("3.14")) }
    check(205) { @d.M5(3.14) }
  end

  def test_reference_parameters
    # todo: implement out params!
  end

  # todo: overload resolution must take into consideration both static and
  # instance methods- don't do this yet!
  def ztest_m81 # static vs. instance overloads ... nasty!
    check(181) { @d.M81(@d, 1) }
  end

  def test_pass_null
    check(120) { @d.M20(nil) }
  end

  def test_overload_with_derived_types
    check(122) { @d.M22(DispatchHelpers::B.new) }
    check(222) { @d.M22(DispatchHelpers::D.new) }
  end

  def test_implicit_upcast_to_interface
    # todo: this is an implicit upcast to an interface - overload resolution
    # algorithm clearly doesn't handle this yet
    #    check(123) { @d.M23(DispatchHelpers::C1.new) }
    check(223) { @d.M23(DispatchHelpers::C2.new) }    
  end

  def test_nullable_types
  end

  def test_m82
    check(182) { Dispatch.M82(true) }
    check(282) { Dispatch.M82('true') }
    # todo: failures while calling via objref must be marshaled correctly to
    # Ruby RuntimeErrors (right now CLR exceptions blow up process)
  end
end

class ReflectionTests < TestCase
  def test_clr_type_name
    assert_equal 'System.Collections.ArrayList', ArrayList.new.clr_type.FullName
  end

  def test_instance_dynamic_bind
    a = ArrayList.new
    assert a.methods.include?('Contains')
    assert a.respond_to?('Contains')
    assert !a.respond_to?('BillyBob')
  end

  def test_instance_verbose_method_reflection
    a = ArrayList.new
    assert a.list_methods(true).include?('Synchronized(System.Collections.IList list)')
  end
  
  def test_static_dynamic_bind
    assert RubyClr::Tests::MarshalerHelper.respond_to?('StaticGetOneDimensionalArray')
    assert !RubyClr::Tests::MarshalerHelper.respond_to?('BillyBob')
  end

  def test_symbols
    assert_equal 'System.Collections.IEnumerable', IEnumerable.to_s
  end
  
  def test_list_interfaces
    interfaces = System::Array.list_interfaces
    assert_equal 4, interfaces.length
    assert_equal 'System.Collections.ICollection', interfaces[0]
    assert_equal 'System.Collections.IEnumerable', interfaces[1]
    assert_equal 'System.ICloneable', interfaces[3]
  end
end

class AutoDisposeTests < TestCase
  def test_simple_dispose
    DisposableClass.disposed = false
    auto_dispose(DisposableClass.new) do |c|
      c.good_method
    end
    assert DisposableClass.Disposed
  end

  def test_exceptional_dispose
    assert_raises RuntimeError do
      DisposableClass.disposed = false
      auto_dispose(DisposableClass.new) do |c|
        c.bad_method
      end
    end
    assert DisposableClass.disposed
  end

  def test_nested_multiple_dispose
    DisposableClass.disposed = false
    AnotherDisposableClass.disposed = false
    auto_dispose(DisposableClass.new) do |dc|
      auto_dispose(AnotherDisposableClass.new) do |adc|
        adc.good_method
      end
      dc.good_method
    end
    assert DisposableClass.disposed
    assert AnotherDisposableClass.disposed
  end

  def test_parallel_multiple_dispose
    DisposableClass.disposed = false
    AnotherDisposableClass.disposed = false
    auto_dispose(DisposableClass.new, AnotherDisposableClass.new) do |dc, adc|
      adc.good_method
      dc.good_method
    end
    assert DisposableClass.disposed
    assert AnotherDisposableClass.disposed
  end
end

include System::ComponentModel

class InterfaceTests < TestCase
  def test_has_interface
    m = System::Data::DataSet.new
    assert m.has_interface?(IComponent)
    assert m.has_interface?(IDisposable)
    assert m.has_interface?(IServiceProvider)
    assert m.has_interface?(IListSource)
    assert m.has_interface?(System::Xml::Serialization::IXmlSerializable)
    assert m.has_interface?(ISupportInitializeNotification)
    assert m.has_interface?(ISupportInitialize)
    assert m.has_interface?(System::Runtime::Serialization::ISerializable)
    assert !m.has_interface?(System::Data::IColumnMapping)
  end
  
  def test_is
    m = System::Data::DataSet.new
    assert m.is?(IComponent)
    assert m.is?(IDisposable)
    assert m.is?(IServiceProvider)
    assert m.is?(IListSource)
    assert m.is?(System::Xml::Serialization::IXmlSerializable)
    assert m.is?(ISupportInitializeNotification)
    assert m.is?(ISupportInitialize)
    assert m.is?(System::Runtime::Serialization::ISerializable)
    assert !m.is?(System::Data::IColumnMapping)
  end

  def test_as
    a = ArrayList.new
    a.add(1)
    e = a.as(IEnumerable).get_enumerator.as(IEnumerator)
    assert e.move_next
    assert 1, e.current
    assert !e.move_next
    assert_equal nil, a.as(IComponent)
  end

  def test_get_interface
    a = ArrayList.new
    e = a.get_interface System::Collections::IEnumerable
    assert_equal 1, e.list_methods.length
    assert e.respond_to?('GetEnumerator')
  end
  
  def test_enumerator
    a = ArrayList.new
    a.Add(1)
    a.Add(2)
    a.Add(3)
    e = a.get_interface(IEnumerable).GetEnumerator.get_interface(IEnumerator)
    assert e.MoveNext
    assert 1, e.Current
    assert e.MoveNext
    assert 2, e.Current
    assert e.MoveNext
    assert 3, e.Current
    assert !e.MoveNext
  end

  def test_enumerator_with_ruby_casing
    a = ArrayList.new
    a.add(1)
    a.add(2)
    a.add(3)
    e = a.get_interface(IEnumerable).get_enumerator.get_interface(IEnumerator)
    assert e.move_next
    assert 1, e.current
    assert e.move_next
    assert 2, e.current
    assert e.move_next
    assert 3, e.current
    assert !e.move_next
  end

  def test_each
    a = ArrayList.new
    a.add(0)
    a.add(1)
    a.add(2)
    sum = 0
    a.each { |item| sum += item }
    assert_equal 3, sum
  end

  def create_test_array
    a = Array.of(Int32).new(4)
    a[0] = 0
    a[1] = 1
    a[2] = 2
    a[3] = 3
    a
  end
  
  def test_each_on_array
    a = create_test_array
    sum = 0
    a.each { |i| sum += i }
    assert_equal 6, sum
  end
  
  def test_collect_on_array
    a = create_test_array
    b = a.collect { |i| i + 1 }
    assert_equal 1, b[0]
    assert_equal 2, b[1]
    assert_equal 3, b[2]
    assert_equal 4, b[3]
  end
  
  def test_each_with_index_on_array
    a = create_test_array
    a.each_with_index do |item, index|
      assert_equal item, index
    end
  end
  
  def test_find_on_array
    a = create_test_array
    assert_equal 0, a.find { |i| i % 2 == 0 }
  end
  
  def test_find_all_on_array
    a = create_test_array
    assert_equal [0, 2], a.find_all { |i| i % 2 == 0 }
  end
  
  def test_inject_on_array
    assert_equal 6, create_test_array.inject(0) { |sum, i| sum += i }
  end
  
  def test_numeric_sort
    a = Array.of(Int32).new(4)
    a[0] = 42
    a[1] = 13
    a[2] = 26
    a[3] = 3
    assert_equal [3, 13, 26, 42], a.sort
  end
  
  def test_alpha_sort
    a = Array.of(System::String).new(4)
    a[0] = 'John'
    a[1] = 'Paul'
    a[2] = 'George'
    a[3] = 'Ringo'
    assert_equal ['George', 'John', 'Paul', 'Ringo'], a.sort
  end
  
  def test_object_sort
    john  = Person.new('John')
    steve = Person.new('Steve')
    mike  = Person.new('Mike')
    
    a = ArrayList.new
    a.add(john)
    a.add(steve)
    a.add(mike)
    
    b = a.sort
    assert_equal Array, b.class
    assert_equal 'John', b[0].name
    assert_equal 'Mike', b[1].name
    assert_equal 'Steve', b[2].name
  end
end

class GenericsTests < TestCase
  include System::Collections::Generic
  
  def test_make_generic_type
    c = List.of(Int32)
    assert_equal 'System::Collections::Generic::List_generic_Int32', c.name
    assert_equal 'System.Collections.Generic.List`1[[System.Int32, mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]', c.clr_type.full_name
  end
  
  def test_create_generic_type
    list = List.of(Int32).new
    assert_equal 'List`1', list.clr_type.name
  end
  
  def test_call_generic_type
    list = List.of(Int32).new
    list.add(42)
    assert_equal 42, list[0]
  end
  
  def test_type_conversion_error
    assert_raises TypeError do
      list = List.of(Int32).new
      list.add('42')
    end
  end

  def test_make_reference_type_generic
    # Note the fully-qualified System::String reference.
    # Otherwise we pickup the Ruby String class ... what to do here?
    list = List.of(System::String).new
    list.add('John')
    list.add('Ruby')
    assert_equal 'John', list[0]
    assert_equal 'Ruby', list[1]
  end

  def test_make_two_parameter_generic_type
    d = Dictionary.of(Int32, Int32)
    assert_equal 'System::Collections::Generic::Dictionary_generic_Int32_Int32', d.name
    assert_equal 'System.Collections.Generic.Dictionary`2[[System.Int32, mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089],[System.Int32, mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]', d.clr_type.full_name
  end

  def test_create_two_parameter_generic_type
    dict = Dictionary.of(Int32, Int32).new
    dict.add(1, 1)
    dict.add(2, 2)
    assert_equal 1, dict[1]
    assert_equal 2, dict[2]
  end

  def test_dictionary_with_string_key
    dict = Dictionary.of(System::String, Int32).new
    dict['John'] = 42
    dict['Ruby'] = 2
    assert_equal 42, dict['John']
    assert_equal 2, dict['Ruby']
  end
  
  def test_marshal_generic_as_return_value
    list = RubyClr::Tests::GenericTestHelper.get_names
    assert_equal 4, list.count
    assert_equal 'John', list[0]
    assert_equal 'Paul', list[1]
    assert_equal 'George', list[2]
    assert_equal 'Ringo', list[3]
  end
  
  def test_marshal_generic_as_parameter
    list = List.of(System::String).new
    list.add('Hello')
    # TODO: better error messages when parameters are reversed!
    RubyClr::Tests::GenericTestHelper.add_name('World', list)
    assert_equal 2, list.count
    assert_equal 'Hello', list[0]
    assert_equal 'World', list[1]
  end
end

class ComparableTests < TestCase
  def test_operators
    bob   = Person.new('Bob')
    john  = Person.new('John')
    john2 = Person.new('John')
    steve = Person.new('Steve')
    assert john == john2
    assert bob < john
    assert steve > john
    assert((john <=> john2) == 0)
    assert((bob <=> john) == -1)
    assert((steve <=> john) == 1)
  end
end

class InlineFilesTests < TestCase
  inline :csharp do |compiler|
    compiler.reference('System.Windows.Forms.dll')
    compiler.compile_file('fibonnaci.cs')
  end
  
  def test_csharp
    assert_equal 8, Fibonnaci.calc(5)
  end
end

class InliningTests < TestCase
  inline :csharp do |compiler|
    compiler.reference('System.Windows.Forms.dll')
    compiler.compile <<-EOF
      namespace Scratch {
        public class Fibonnaci {
          public static decimal Calc(long n) {
            decimal x1 = 1, x2 = 2, tmp;
            for (long i = 1; i < n; ++i) {
              x1 += x2;
              tmp = x2; x2 = x1; x1 = tmp;
            }
            return x1;
          }
          public static void SayHello() {
            System.Windows.Forms.MessageBox.Show("Hello, World!");
          }
        }
      }
    EOF
  end
    
  inline :vb do |compiler|
    compiler.compile <<-EOF
      Namespace VBScratch
        Public Class Fibonnaci
          Public Shared Function Calc(n As Long) As Decimal
            Dim x1 As Decimal = 1
            Dim x2 As Decimal = 2
            Dim tmp As Decimal
            Dim i As Long
            For i = 1 To n - 1
              x1 = x1 + x2
              tmp = x2
              x2 = x1
              x1 = tmp
            Next
            Return x1
          End Function
        End Class
      End Namespace
    EOF
  end

  inline :jscript do |compiler|
    compiler.compile <<-EOF
      class JScriptClass {
        function sayHello() {
          return "hello"
        }
      }
    EOF
  end
  
  def test_inline_csharp
    assert_equal 8, Scratch::Fibonnaci.calc(5)
  end
  
  def test_inline_vb
    assert_equal 8, VBScratch::Fibonnaci.calc(5)
  end
  
  def test_inline_jscript
    assert_equal 'hello', JScriptClass.new.sayHello
  end
end

class DisposableObject
  implements IDisposable
  
  def initialize
    @disposed = false
  end
  
  def dispose
    @disposed = true
  end
  
  def is_disposed?
    @disposed
  end
end

class DerivedDisposableObject < DisposableObject
end

class InterfaceImplementationTests < TestCase
  inline :csharp do |compiler|
    compiler.compile <<-EOF
      namespace RubyClr.Tests {
        public class MarshalTarget {
          public static void TestDispose(System.IDisposable obj) {
            obj.Dispose();
          }
        }
      }
    EOF
  end

  def test_marshal_disposable_object
    object = DisposableObject.new
    assert(!object.is_disposed?)
    MarshalTarget.test_dispose(object)
    assert(object.is_disposed?)
  end
  
  def test_marshal_derived_disposable_object
    object = DerivedDisposableObject.new
    assert(!object.is_disposed?)
    MarshalTarget.test_dispose(object)
    assert(object.is_disposed?)
  end
end

class CamelCaseConversionTests < TestCase
  def test_ruby_case_conversions
    assert_equal 'array_list', Identifier::to_ruby_case('arrayList')
    assert_equal 'array_list', Identifier::to_ruby_case('ArrayList')
    assert_equal 'one_two_three', Identifier::to_ruby_case('OneTwoThree')
    assert_equal 'one_two_three', Identifier::to_ruby_case('oneTwoThree')
    assert_equal 'one_two_thre_e', Identifier::to_ruby_case('OneTwoThreE')
  end

  def test_camel_case_conversions
    assert_equal 'Count', Identifier::to_camel_case('count')
    assert_equal 'MoveNext', Identifier::to_camel_case('move_next')
    assert_equal 'DeserializeMethodResponse', Identifier::to_camel_case('deserialize_method_response')
    assert_equal 'Countdown', Identifier::to_camel_case('CountDown')
    assert_equal 'DataSource=', Identifier::to_camel_case('data_source=')
  end
end

class DataBinderTests < TestCase
  inline :csharp do |compiler|
    compiler.compile <<-EOF
      using System.Collections;
      namespace RubyClr.Tests {
        public class RubyArrayDataBindingTarget {
          public static int[] EnumArray(IEnumerable obj) {
            ArrayList al = new ArrayList();
            foreach(int current in obj)
              al.Add(current);
            return (int[])al.ToArray(typeof(int));
          }
        }
      }
    EOF
  end

  def test_array_bind
    numbers = [1, 2, 3, 4, 5]
    result = RubyArrayDataBindingTarget.enum_array(numbers)
    assert_equal 1, result[0]
    assert_equal 5, result[4]
  end

  def test_bind
    a = ['John', 'Paul', 'George', 'Ringo']
    c = List.of(System::String)
    list = RubyClr::Tests::DataBinderTestHelper.bind(a)
    assert_equal 4, list.count
    assert_equal 'John', list[0]
    assert_equal 'Paul', list[1]
    assert_equal 'George', list[2]
    assert_equal 'Ringo', list[3]
  end
  
  def test_add_elements_to_ruby_array
    numbers = [1, 2]
    DataBinderTestHelper.add_elements_to_ruby_array(numbers)
    assert_equal 4, numbers.length
    assert_equal 3, numbers[2]
    assert_equal 4, numbers[3]
  end
  
  def test_clear_elements_in_ruby_array
    numbers = [1, 2, 3, 4]
    DataBinderTestHelper.clear_elements(numbers)
    assert_equal 0, numbers.length
  end
  
  def test_insert_elements_at_start_of_ruby_array
    numbers = [3, 4]
    DataBinderTestHelper.insert_elements_at_start_of_ruby_array(numbers)
    assert_equal 4, numbers.length
    assert_equal 1, numbers[0]
    assert_equal 2, numbers[1]
  end
  
  def test_contains_a_one
    numbers = [1, 2]
    assert DataBinderTestHelper.contains_a_one(numbers)
  end
  
  def test_not_contains_a_one
    numbers = [2, 3]
    assert !DataBinderTestHelper.contains_a_one(numbers)
  end
  
  def test_index_of
    numbers = [1, 2, 3, 4]
    assert_equal 3, DataBinderTestHelper.get_index_of_four(numbers)
  end
  
  def test_remove_three
    numbers = [1, 2, 3, 4]
    DataBinderTestHelper.remove_three(numbers)
    assert_equal 3, numbers.length
    assert_equal 4, numbers[2]
    assert_equal 2, numbers[1]
    assert_equal 1, numbers[0]
    assert_equal 1, numbers.first
  end

  def test_remove_first_element
    numbers = [1, 2, 3, 4]
    DataBinderTestHelper.remove_first_element(numbers)
    assert_equal 3, numbers.length
    assert_equal 2, numbers.first
    assert_equal 3, numbers[1]
    assert_equal 4, numbers.last
  end
  
  def test_remove_second_element
    numbers = [1, 2, 3, 4]
    DataBinderTestHelper.remove_second_element(numbers)
    assert_equal 3, numbers.length
    assert_equal 1, numbers.first
    assert_equal 3, numbers[1]
    assert_equal 4, numbers.last
  end
  
  def test_modify_array_elements
    numbers = [1, 2, 3, 4]
    DataBinderTestHelper.add_one_to_each_element(numbers)
    assert_equal 4, numbers.length
    assert_equal 2, numbers.first
    assert_equal 3, numbers[1]
    assert_equal 4, numbers[2]
    assert_equal 5, numbers.last
  end
end

class NullValueAssignmentTests < TestCase
  def test_simple_null_assignment
    obj = NullablePropertyTestTargets.new
    assert_equal 'default', obj.property
    obj.property = nil
    assert_equal nil, obj.property
    obj.property = 'new'
    assert_equal 'new', obj.property
  end
  
  def test_retrieve_null_non_string_object_reference
    obj = NullablePropertyTestTargets.new
    assert_equal nil, obj.person
    john = Person.new('John')
    obj.person = john
    assert_equal john, obj.person
    # john.name = 'Steve' # this is a read-only property - error message blows
  end
  
  def test_retrieve_null_interface
    obj = NullablePropertyTestTargets.new
    assert_equal nil, obj.get_null_interface
  end
end

# This test case exists to reproduce the DateTime marshaling bugs
# It turns out that DateTime structs are autolayout as opposed to Point
# structs that are sequential layout. I can blit a Point, but can't with a DateTime
# due to the autolayout. So I need to explicitly marshal a DateTime across
# the interop boundary (and any other value type that is not blittable). Yuck.

class DateTimeMarshalerTests < TestCase
  def test_get_datetime
    x = DateTimeTestTargets.get_current_date
    assert DateTimeTestTargets.compare_with_now(x)
  end
  
  # TODO: reveals two new bugs: need to upconvert int32 to int64 parameters so that single arg ctor of DateTime will succeed
  # TODO: need to box value types passed to object array parameters 
  def test_create_datetime
    x = System::DateTime.new(2006, 2, 2)
    assert_equal 2006, x.year
    assert_equal 2, x.month
    assert_equal 2, x.day
  end
end

class DataBindingTests < TestCase
  inline :vb do |compiler|
    compiler.compile <<-EOF
      Namespace RubyClr.Tests
        Public Class MarshalToClrHelpers
          Public Shared Function ConvertToString(rubyObj as Object) As String
            Return rubyObj.ToString()
          End Function
          Public Shared Function ReturnName(rubyObj as Object) As String
            Return rubyObj.Name
          End Function
          Public Shared Sub ChangeName(rubyObj as Object)
            rubyObj.Name = "Mike"
          End Sub
        End Class
      End Namespace
    EOF
  end

  ActiveRecord::Base.establish_connection(:adapter => 'sqlserver', :host => '.\SQLEXPRESS', :database => 'rubyclr_tests')

  class Person < ActiveRecord::Base
    implements INotifyPropertyChanged
 
    def to_s
      "My name is #{name} and I am #{age} years old"
    end
    
    def name=(value)
      write_attribute("name", value)
      if defined?(@clr_shadow_object)
        if @clr_shadow_object.property_changed != nil
          @clr_shadow_object.property_changed.invoke(@clr_shadow_object, PropertyChangedEventArgs.new('name'))
        end
      end
    end
  end
  
  def test_simple_callback
    john = Person.find_all.first
    assert_equal 'My name is John and I am 38 years old', MarshalToClrHelpers.convert_to_string(john)
    assert_equal 'John', MarshalToClrHelpers.return_name(john)
  end
  
  def test_set_property_from_clr
    john = Person.find_all.first
    MarshalToClrHelpers.change_name(john)
    assert_equal 'Mike', john.name
  end

  Employee = Struct.new(:name, :age)
  
  class Employee
    def to_s
      "My name is #{name} and I am #{age} years old"
    end
  end
  
  def test_employee_callback
    john = Employee.new('John', '38')
    assert_equal 'My name is John and I am 38 years old', MarshalToClrHelpers.convert_to_string(john)
    MarshalToClrHelpers.change_name(john)
    assert_equal 'Mike', john.name
  end
end

class ValueTypeBoxingTests < TestCase
  inline :csharp do |compiler|
    compiler.reference 'System.Drawing.dll'
    compiler.compile <<-EOF
      using System;
      using System.Drawing;
      namespace RubyClr.Tests {
        public class ValueTypeBoxingTestHelpers {
          public static Point PrintPoint(object boxedPoint) {
            return (Point)boxedPoint;
          }
        }
      }
    EOF
  end

  def test_value_type_box_round_trip
    point = Point.new(3, 4)
    result = ValueTypeBoxingTestHelpers.print_point(point)
    assert_equal 3, result.x
    assert_equal 4, result.y
    assert_equal 'System.Drawing.Point', result.clr_type.full_name
  end    
  
  def test_marshal_guid
    a = ArrayList.new
    g = Guid.new('ffffffff-ffff-ffff-ffff-ffffffffffff')
    bytes = g.to_byte_array
    assert_equal 16, bytes.length
    bytes.each { |byte| assert_equal 255, byte }
    a.add(g)
    g2 = a[0]
    assert_equal 'System.Guid', g2.clr_type.full_name
    bytes_g = g2.to_byte_array
    assert_equal 16, bytes_g.length
    bytes.each { |byte| assert_equal 255, byte }
  end
end

class IdentityTests < TestCase
  Employee = Struct.new(:name, :age)

  inline :csharp do |compiler|
    compiler.compile <<-EOF
      using System.Collections;
      namespace RubyClr.Tests {
        public class ByRefObject {
        }
        
        public class IdentityTestHelpers {
          public static bool AreEqual(IList list) {
            return list[0] == list[0];
          }
          
          public static bool AreEqual2(object lhs, object rhs) {
            return lhs == rhs;
          }
          
          public static bool AreDifferent(IList list) {
            return list[0] != list[1];
          }
          
          public static bool AreDifferent2(object lhs, object rhs) {
            return lhs != rhs;
          }
          
          public static string[] GetStringArray() {
            return new string[] { "a", "b", "c" };
          }
          
          public static ByRefObject[] GetByRefObjectArray() {
            return new ByRefObject[] { new ByRefObject(), new ByRefObject() };
          }
        }
      }
    EOF
  end
      
  def test_identity
    john = Employee.new('John', 38)
    ben  = Employee.new('Ben', 0)
    
    employees = [john, ben]

    assert IdentityTestHelpers.are_equal(employees)
    
    # TODO: we have a bug with static overloaded method resolution
    # This is why this is a different method name for now
    assert IdentityTestHelpers.are_equal2(employees[0], employees[0])
    
    assert IdentityTestHelpers.are_different(employees)
    assert IdentityTestHelpers.are_different2(employees[0], employees[1])
  end
  
  # Strings are marshaled by value across interop boundary so we expect
  # retrieving the same string twice to have different ruby object identities
  def test_string_identity
    strings = IdentityTestHelpers.get_string_array
    assert_equal 3, strings.length

    a, b = strings[0], strings[0]
    assert_equal a, b                          # strings are equal in value 
    assert_not_equal a.object_id, b.object_id  # ruby identity different because of marshal by value
  end
  
  def test_by_ref_object_identity
    objects = IdentityTestHelpers.get_by_ref_object_array
    assert_equal 2, objects.length

    a, b = objects[0], objects[0]
    assert_equal a.object_id, b.object_id         # ruby identity
    assert_equal a.get_hash_code, b.get_hash_code # CLR identity

    c, d = objects[0], objects[1]    
    assert_not_equal c.object_id, d.object_id
    assert_not_equal c.get_hash_code, d.get_hash_code
  end
end
