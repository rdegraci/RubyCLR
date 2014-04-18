#include "stdafx.h"
#include "RubyHelpers.h"
#include "Utility.h"
#include "Marshal.h"

namespace RubyClr {
  extern "C" {
    void release_object(void *objref) {
      if (objref != 0 && *((int*)objref) != 0) {
        int *objectReference = (int*)objref;
        GCHandle handle = (GCHandle)(IntPtr)*objectReference;
        int hashCode = handle.Target->GetHashCode();
        Identity::RemoveProxyObject(hashCode);
        handle.Free();
        xfree(objectReference);
      }
    }

    VALUE alloc_clr_object(VALUE klass) {
      if (rb_iv_get(klass, "@is_value_type") == Qtrue) {
        int valueTypeSize   = FIX2LONG(rb_iv_get(klass, "@value_type_size")); 
        void *valueTypeBlob = ruby_xmalloc(valueTypeSize);
        return Data_Wrap_Struct(klass, 0, 0, valueTypeBlob);
      }
      else {
        int *objectReference = ALLOC(int);
        *objectReference     = 0;
        return Data_Wrap_Struct(klass, 0, release_object, objectReference);
      }
    }
  }

  VALUE Marshal::GetRubyClassObject(String^ rubyClassName) {
    if (TypeNameToClassObject.ContainsKey(rubyClassName)) 
      return TypeNameToClassObject[rubyClassName];
    else 
      return Ruby::EvalString(rubyClassName->Replace(".", "::")->Replace("+", "::"));
  }

  VALUE Marshal::GetRubyClassObject(Type^ type) {
    return GetRubyClassObject(Ruby::TypeToRubyShadowClassName(type));
  }

  // Custom Ruby allocator functions
  VALUE Marshal::AssignToClassInstance(VALUE self, Object^ object) {
    GCHandle objref      = GCHandle::Alloc(object);
    int *objectReference = (int*)DATA_PTR(self);
    *objectReference     = ((IntPtr)objref).ToInt32();
    return Qnil;
  }

  // Conversions TO Ruby
  VALUE Marshal::ToRubyString(String^ string) {
    return Ruby::ToRubyString(string);
  }

  // This internal method is used only to wrap CLR objects that we don't want to be 
  // callable from Ruby code.
  VALUE RubyClr::Marshal::ToRubyObjectByRefInternal(Object^ object) {
    if (object == nullptr) return Qnil;
    GCHandle objref      = GCHandle::Alloc(object);
    int *objectReference = ALLOC(int);
    *objectReference     = ((IntPtr)objref).ToInt32();
    return Data_Wrap_Struct(rb_cObject, 0, release_object, objectReference);
  }

  VALUE RubyClr::Marshal::ToRubyEnum(String^ enumName, int value) {
    VALUE class_object = GetRubyClassObject(enumName);
    return rb_funcall(class_object, rb_intern("lookup"), 1, Marshal::ToRubyNumber(value));
  }

  VALUE RubyClr::Marshal::ToRubyObjectByValue(String^ valueTypeClassName, void *value_type) {
    VALUE class_object = GetRubyClassObject(valueTypeClassName);
    return Data_Wrap_Struct(class_object, 0, 0, value_type); 
  }

  // This method needs to lookup in a hashtable to see whether we already have a Ruby object
  // allocated for this object id. If we do, then we return that Ruby object to preserve
  // identity across the interop boundary.

  // TODO: This breaks stuff something awful. I need to track down the root cause since I'm 
  // sure that some combination of GC + other stuff is causing it to blow chunks.
  // Disabling GC in ruby helps the code run a bit longer (need to store this in a Ruby hash)
  // but it blows on another interesting case but at least it seems reproducible.
  VALUE RubyClr::Marshal::ToRubyObjectByRef(VALUE class_object, Object^ object) {
    if (object == nullptr) return Qnil;

    int hashCode = object->GetHashCode();
    VALUE proxyObject = Identity::GetProxyObject(hashCode);
    if (proxyObject != Qnil) return proxyObject;

    GCHandle objref      = GCHandle::Alloc(object);
    int *objectReference = ALLOC(int);
    *objectReference     = ((IntPtr)objref).ToInt32();
    proxyObject = Data_Wrap_Struct(class_object, 0, release_object, objectReference);
    
    Identity::CacheProxyObject(hashCode, proxyObject);
    return proxyObject;
  }

  VALUE RubyClr::Marshal::ToRubyObjectAsInterface(String^ interfaceName, Object^ object) {
    if (object == nullptr) return Qnil;
    VALUE class_object = GetRubyClassObject(interfaceName);

    // TODO: I break identity with interface proxies since I'm implementing this stuff as 
    // independent objects right now. 
    GCHandle objref      = GCHandle::Alloc(object);
    int *objectReference = ALLOC(int);
    *objectReference     = ((IntPtr)objref).ToInt32();
    return Data_Wrap_Struct(class_object, 0, release_object, objectReference);
  }

  Object^ RubyClr::Marshal::BoxValueType(VALUE object) {
    VALUE klass = rb_class_of(object);
    int   size  = FIX2INT(rb_iv_get(klass, "@value_type_size"));
    Type^ type  = (Type^)Marshal::ToObjectInternal(rb_iv_get(klass, "@clr_type"));

    Object^ boxedInstance = Activator::CreateInstance(type);
    GCHandle handle       = GCHandle::Alloc(boxedInstance, GCHandleType::Pinned);

    try {
      Int32* target = (Int32*)(void*)handle.AddrOfPinnedObject();
      void* source  = DATA_PTR(object);
      memcpy(target, source, size);
    }
    finally {
      handle.Free();
    }
    return boxedInstance;
  }

  VALUE RubyClr::Marshal::UnBoxValueType(Object^ object, String^ valueTypeName) {
    if (object == nullptr) return Qnil;

    VALUE class_object = GetRubyClassObject(valueTypeName);
    int size           = FIX2INT(rb_iv_get(class_object, "@value_type_size"));
    
    GCHandle handle    = GCHandle::Alloc(object, GCHandleType::Pinned);

    try {
      Int32* source = (Int32*)(void*)handle.AddrOfPinnedObject();
      void* target  = ruby_xmalloc(size);
      memcpy(target, source, size);
      return Data_Wrap_Struct(class_object, 0, 0, target); 
    }
    finally {
      handle.Free();
    }
  }

  VALUE RubyClr::Marshal::ToRubyObject(Object^ object) {
    if (object == nullptr) return Qnil;

    Type^ objectType = object->GetType();

    // If an object can be marshaled by value, we do the correct conversion
    if (objectType == Boolean::typeid) return ToRubyBoolean((Boolean)object);
    if (objectType == SByte::typeid)   return ToRubyNumber((SByte)object);
    if (objectType == Int16::typeid)   return ToRubyNumber((Int16)object);
    if (objectType == Int32::typeid)   return ToRubyNumber((Int32)object);
    if (objectType == Int64::typeid)   return ToRubyNumber((Int64)object);
    if (objectType == Byte::typeid)    return ToRubyNumber((Byte)object);
    if (objectType == UInt16::typeid)  return ToRubyNumber((UInt16)object);
    if (objectType == UInt32::typeid)  return ToRubyNumber((UInt32)object);
    if (objectType == UInt64::typeid)  return ToRubyNumber((UInt64)object);
    if (objectType == String::typeid)  return ToRubyString((String^)object);
    if (objectType == Single::typeid)  return ToRubyNumber((Single)object);
    if (objectType == Double::typeid)  return ToRubyNumber((Double)object);      

    // This could be a boxed value type
    if (objectType->IsValueType) 
      return UnBoxValueType(object, objectType->FullName);

    VALUE class_object = GetRubyClassObject(objectType);
    return ToRubyObjectByRef(class_object, object);
  }

  VALUE RubyClr::Marshal::ToRubyString(Int64 value)   { return ToRubyString(Convert::ToString(value)); }
  VALUE RubyClr::Marshal::ToRubyString(Int32 value)   { return ToRubyString(Convert::ToString(value)); }
  VALUE RubyClr::Marshal::ToRubyString(Int16 value)   { return ToRubyString(Convert::ToString(value)); }
  VALUE RubyClr::Marshal::ToRubyString(SByte value)   { return ToRubyString(Convert::ToString(value)); }

  VALUE RubyClr::Marshal::ToRubyString(UInt64 value)  { return ToRubyString(Convert::ToString(value)); }
  VALUE RubyClr::Marshal::ToRubyString(UInt32 value)  { return ToRubyString(Convert::ToString(value)); }
  VALUE RubyClr::Marshal::ToRubyString(UInt16 value)  { return ToRubyString(Convert::ToString(value)); }
  VALUE RubyClr::Marshal::ToRubyString(Byte value)    { return ToRubyString(Convert::ToString(value)); }
  VALUE RubyClr::Marshal::ToRubyString(Boolean value) { return ToRubyString(Convert::ToString(value)); }

  VALUE RubyClr::Marshal::ToRubyNumber(Int64 value)   { return rb_ll2inum(value); }
  VALUE RubyClr::Marshal::ToRubyNumber(Int32 value)   { return rb_int2inum(value); }
  VALUE RubyClr::Marshal::ToRubyNumber(Int16 value)   { return rb_int2inum(value); }
  VALUE RubyClr::Marshal::ToRubyNumber(SByte value)   { return rb_int2inum(value); }

  VALUE RubyClr::Marshal::ToRubyNumber(UInt64 value)  { return rb_ull2inum(value); }
  VALUE RubyClr::Marshal::ToRubyNumber(UInt32 value)  { return rb_uint2inum(value); }
  VALUE RubyClr::Marshal::ToRubyNumber(UInt16 value)  { return rb_uint2inum(value); }
  VALUE RubyClr::Marshal::ToRubyNumber(Byte value)    { return rb_uint2inum(value); }

  VALUE RubyClr::Marshal::ToRubyNumber(Double value)  { return rb_float_new(value); }
  VALUE RubyClr::Marshal::ToRubyNumber(Single value)  { return rb_float_new(value); }

  VALUE RubyClr::Marshal::ToRubyNumber(Decimal value) {
    VALUE val = Marshal::ToRubyString(value.ToString());
    return rb_funcall(g_big_decimal_class, rb_intern("new"), 1, val);
  }

  VALUE RubyClr::Marshal::ToRubyBoolean(bool value)   { return value ? Qtrue : Qfalse; }
  VALUE RubyClr::Marshal::ToRubyNil()                 { return Qnil; }

  void RubyClr::Marshal::ToRubyException(Exception^ e) { rb_raise(rb_eRuntimeError, "%s", e->ToString()); }

  // Conversions FROM Ruby
  String^ RubyClr::Marshal::ToClrString(VALUE string) {
    if (string == Qnil) return nullptr;
    return gcnew String(RSTRING(string)->ptr); 
  }

  Boolean RubyClr::Marshal::ToBoolean(VALUE value) { 
    if (value == Qtrue)  return true;
    if (value == Qfalse) return false;
    rb_raise(rb_eRuntimeError, "Expected a boolean but was passed something else");
  }

  Int64  RubyClr::Marshal::ToInt64(VALUE value)  { return rb_num2ll(value); }
  UInt64 RubyClr::Marshal::ToUInt64(VALUE value) { return rb_num2ull(value); }

  Int32  RubyClr::Marshal::ToInt32(VALUE value)  { return rb_num2long(value); }
  UInt32 RubyClr::Marshal::ToUInt32(VALUE value) { return rb_num2ulong(value); }

  Int16  RubyClr::Marshal::ToInt16(VALUE value)  { return Convert::ToInt16(ToInt32(value)); }
  SByte  RubyClr::Marshal::ToSByte(VALUE value)  { return Convert::ToSByte(ToInt32(value)); }

  UInt16 RubyClr::Marshal::ToUInt16(VALUE value) { return Convert::ToInt16(ToUInt32(value)); }
  Byte   RubyClr::Marshal::ToByte(VALUE value)   { return Convert::ToByte(ToUInt32(value)); }

  Double RubyClr::Marshal::ToDouble(VALUE value) { return Convert::ToDouble(rb_num2dbl(value)); }
  Single RubyClr::Marshal::ToSingle(VALUE value) { return Convert::ToSingle(rb_num2dbl(value)); }

  // HACK:: does this actually work with non-integral enums? try with enum: byte? no it doesn't - it crashes. Need to implement a switch here?
  // NOTE:: enums can actually be based on floats as well! (CLR lets this happen, languages don't)
  int RubyClr::Marshal::ToEnum(VALUE value) {
    return RubyClr::Marshal::ToInt32(rb_iv_get(value, "@value"));
  }

  bool RubyClr::Marshal::ImplementsInterfaces(VALUE object) {
    VALUE respond_to = rb_funcall(object, rb_intern("respond_to?"), 1, ID2SYM(rb_intern("clr_interfaces")));
    return respond_to == Qfalse ? false : true;
  }

  bool RubyClr::Marshal::IsValueType(VALUE object) {
    VALUE klass = rb_class_of(object);
    return rb_funcall(klass, rb_intern("is_value_type?"), 0) == Qtrue;
  }

  Object^ RubyClr::Marshal::ToObjectInternal(VALUE object) {
    if (object == Qnil) return nullptr;

    VALUE klass = rb_class_of(object);
    if (rb_ivar_defined(klass, rb_intern("@is_value_type")) && rb_iv_get(klass, "@is_value_type") == Qtrue) 
//      return DynamicCode::BoxValueType(object);
      return BoxValueType(object);
    else {
      int *objectReference;
      Data_Get_Struct(object, int, objectReference);
      return ((GCHandle)(IntPtr)*objectReference).Target;
    }
  }

  Object^ RubyClr::Marshal::ToClrCallableRubyObject(VALUE object) {
    VALUE clr_type = rb_funcall(rb_const_get(rb_cObject, rb_intern("Generate")), rb_intern("marshal_ruby_object_to_clr"), 1, object);
    Type^ type     = (Type^)Marshal::ToObjectInternal(clr_type);
    Object^ result = Activator::CreateInstance(type, gcnew array<Object^> { object });

    // Pin Ruby object to global hashtable to keep it from being GC'd
    VALUE object_id = rb_funcall(object, rb_intern("object_id"), 0);
    rb_funcall(g_ruby_object_handles, rb_intern("[]="), 2, object_id, object);

    String^ clrShadowClassName = type->FullName;
    ID clrShadowClassId        = rb_intern(STR2CSTR(Marshal::ToRubyString(clrShadowClassName)));
    VALUE ruby_shadow_class    = rb_const_get(rb_cObject, clrShadowClassId);

    if (ruby_shadow_class == Qnil) {
      ruby_shadow_class = ShadowClass::CreateRubyShadowClass(type, clrShadowClassName);
      rb_const_set(rb_cObject, clrShadowClassId, ruby_shadow_class);
    }

    VALUE clr_shadow_object = Marshal::ToRubyObjectByRef(ruby_shadow_class, result);
    rb_iv_set(object, "@clr_shadow_object", clr_shadow_object);
    return result;
  }

  bool RubyClr::Marshal::IsBindable(VALUE object) {
    if (rb_const_defined(rb_cObject, rb_intern("RubyClr"))) {
      VALUE active_record = rb_const_get(rb_cObject, rb_intern("RubyClr"));
      if (rb_const_defined(active_record, rb_intern("Bindable"))) {
        VALUE base = rb_const_get(active_record, rb_intern("Bindable"));
        return rb_funcall(rb_funcall(rb_class_of(object), rb_intern("ancestors"), 0), rb_intern("include?"), 1, base) == Qtrue;
      }
    }
    return false;
  }

  Object^ RubyClr::Marshal::ToObject(VALUE object) {
    // If a type that can be marshaled by value, then we convert and marshal. Currently this stuff is here to
    // support boxing scenarios. Should boxing be something that's done in the shims or in the marshalers?
    if (object == Qtrue || object == Qfalse)    return object == Qtrue;
    if (TYPE(object) == T_STRING)               return ToClrString(object);
    if (FIXNUM_P(object))                       return ToInt32(object);
    if (rb_obj_is_kind_of(object, rb_cNumeric)) return ToDouble(object);

    // Object is a marshal by reference only type 
    if (object == Qnil) return nullptr;
    if (TYPE(object) == T_DATA)
      return ToObjectInternal(object);

    // If we have already created a CLR shadow object, then we marshal that - required to preserve identity
    if (rb_ivar_defined(object, rb_intern("@clr_shadow_object"))) {
      VALUE clr_shadow_object = rb_iv_get(object, "@clr_shadow_object");
      if (clr_shadow_object != Qnil)
        return ToObjectInternal(clr_shadow_object);
    }

    // Wrap objects that implement interfaces or are data-bindable
    if (rb_respond_to(object, rb_intern("clr_interfaces")) == Qtrue || IsBindable(object))
      return ToClrCallableRubyObject(object);
    else
      return ToObjectInternal(object);
  }
}