#pragma once

extern VALUE g_big_decimal_class;

namespace RubyClr {
  extern "C" {
    void release_object(void *objref);
    VALUE alloc_clr_object(VALUE klass);
  }

  public ref class Marshal {
  public:
    static Dictionary<String^, VALUE> TypeNameToClassObject;

    static VALUE GetRubyClassObject(String^ rubyClassName);
    static VALUE GetRubyClassObject(Type^ type);
    static VALUE AssignToClassInstance(VALUE self, Object^ object);

    // Conversions TO Ruby
    static VALUE ToRubyString(String^ string);
    static VALUE ToRubyObjectByRefInternal(Object^ object);
    static VALUE ToRubyEnum(String^ enumName, int value);
    static VALUE ToRubyObjectByValue(String^ valueTypeClassName, void *value_type);
    static VALUE ToRubyObjectByRef(VALUE class_object, Object^ object);
    static VALUE ToRubyObjectAsInterface(String^ interfaceName, Object^ object);
    static VALUE ToRubyObject(Object^ object);

    static VALUE ToRubyString(Int64 value);
    static VALUE ToRubyString(Int32 value);
    static VALUE ToRubyString(Int16 value);
    static VALUE ToRubyString(SByte value);

    static VALUE ToRubyString(UInt64 value);
    static VALUE ToRubyString(UInt32 value);
    static VALUE ToRubyString(UInt16 value);
    static VALUE ToRubyString(Byte value);
    static VALUE ToRubyString(Boolean value);

    static VALUE ToRubyNumber(Int64 value);
    static VALUE ToRubyNumber(Int32 value);
    static VALUE ToRubyNumber(Int16 value);
    static VALUE ToRubyNumber(SByte value);
    
    static VALUE ToRubyNumber(UInt64 value);
    static VALUE ToRubyNumber(UInt32 value);
    static VALUE ToRubyNumber(UInt16 value);
    static VALUE ToRubyNumber(Byte value);

    static VALUE ToRubyNumber(Double value);
    static VALUE ToRubyNumber(Single value);

    static VALUE ToRubyNumber(Decimal value);

    static VALUE ToRubyBoolean(bool value);
    static VALUE ToRubyNil();

    static void ToRubyException(Exception^ e);

    // Conversions FROM Ruby
    static String^ ToClrString(VALUE string);

    static Boolean ToBoolean(VALUE value);

    static Int64  ToInt64(VALUE value);
    static UInt64 ToUInt64(VALUE value);

    static Int32  ToInt32(VALUE value);
    static UInt32 ToUInt32(VALUE value);

    static Int16  ToInt16(VALUE value);
    static SByte  ToSByte(VALUE value);

    static UInt16 ToUInt16(VALUE value);
    static Byte   ToByte(VALUE value);

    static Double ToDouble(VALUE value);
    static Single ToSingle(VALUE value);

    static int ToEnum(VALUE value);
    static bool ImplementsInterfaces(VALUE object);
    static bool IsBindable(VALUE object);
    static bool IsValueType(VALUE object);

    static Object^ BoxValueType(VALUE object);
    static VALUE UnBoxValueType(Object^ object, String^ valueTypeName);

    static Object^ ToObjectInternal(VALUE object);
    static Object^ ToClrCallableRubyObject(VALUE object);
    static Object^ ToObject(VALUE object);
  };
}