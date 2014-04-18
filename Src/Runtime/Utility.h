#pragma once

extern VALUE g_generator;
extern VALUE g_ruby_object_handles;
extern VALUE g_ruby_identity_map;

using namespace System::ComponentModel;

namespace RubyClr {
  public delegate VALUE RubyMethod(int argc, VALUE *args, VALUE self);
  public delegate int SizeOfEventHandler();
  public delegate Object^ ValueTypeMarshalerEventHandler(Type^, VALUE, Int32);

  ref class Identity {
  public:
    static VALUE GetProxyObject(int hashCode);
    static void CacheProxyObject(int hashCode, VALUE proxyObject);
    static void RemoveProxyObject(int hashCode);
  };

  ref class DynamicCode {
    static ValueTypeMarshalerEventHandler^ _boxValueTypeMethod;
  public:
    static Object^ BoxValueType(VALUE value);
  };

  ref class VariableDictionary : Dictionary<String^, LocalBuilder^> {};

  ref class LabelDictionary : Dictionary<String^, System::Reflection::Emit::Label> {
  public:
    System::Reflection::Emit::Label GetOrCreateLabel(ILGenerator^ g, VALUE label_name);
  };

  ref class ShadowClassDictionary : Dictionary<String^, Type^> {};

  ref class CodeGenerator {
  public:
    static VALUE CreateNamespaceList();
    static VALUE CreateGenerator(VALUE generator, VALUE ruby_obj_field, VALUE method_name);
    static VALUE CreateGenerator(VALUE generator);
  };

  public ref class ClrShadowClass {
  protected:
    VALUE ruby_obj_ref;
  public:
    virtual String^ ToString() override;
#pragma warning(disable:4461)
// TODO: Implement Dispose() below once I understand how to implement IDisposable in a derived class
//    virtual ~ClrShadowClass();
    !ClrShadowClass();
  };

  ref class ShadowClass {
    static String^ ToCamelCase(VALUE attribute);
    static ShadowClassDictionary^ _cache = gcnew ShadowClassDictionary();
    static String^ GetRandomName();
    static String^ GetInterfaceName(VALUE itf);

    // TODO: next two methods are duplicated from RubyType. Need to refactor this stuff somewhere else
    static VALUE CreateSignature(array<Type^>^ signature);
    static VALUE CreateSignatureArray(array<Type^>^ parameters);

    static TypeBuilder^ CreateAnonymousType();
    static FieldInfo^ CreateConstructorAndField(TypeBuilder^ tb);
    static Type^ GetAttributeType(VALUE obj, VALUE attribute_name);
    static MethodBuilder^ GenerateMethod(TypeBuilder^ tb, FieldInfo^ rubyObjRefField, String^ methodName, MethodAttributes methodAttributes, String^ shimMethodName, Type^ returnType, array<Type^>^ parameterTypes, String^ memberType);
    static void GenerateMethods(TypeBuilder^ tb, FieldInfo^ rubyObjRefField, Type^ itf);
    static void GenerateProperties(TypeBuilder^ tb, FieldInfo^ rubyObjRefField, VALUE obj);
    static void GenerateEvents(TypeBuilder^ tb, Type^ itf);
    static Type^ Create(VALUE interfaces);
    static int GetSizeOfValueTypeHack(Type^ type);
    static List<String^>^ GenerateMethodExemptionList(Type^ itf);
  public:
    static VALUE CloneValueType(VALUE self);
    static VALUE CreateRubyShadowClass(Type^ type, String^ typeName);
    static Type^ CreateClrShadowClass(VALUE interfaces);
    static property ShadowClassDictionary^ Cache {
      ShadowClassDictionary^ get();
    };
  };

  // TODO: Note that this is totally un-optimized. Need to converge on a tree to optimize # tests.
  public ref class RuntimeResolver {
    static Type^ MapRubyTypeToDotNetType(VALUE object);
    static array<Type^>^ GetParameterTypes(int argc, VALUE *args);
    static bool IsExactMatch(array<Type^>^ rubyParameterTypes, array<Type^>^ methodParameterTypes);
    static bool IsMatchParameterArray(array<Type^>^ rubyParameterTypes, array<Type^>^ methodSignatureTypes);
    static int FindBestMatch(array<Type^>^ rubyParameterTypes, array<array<Type^>^>^ methodSignatures, array<bool>^ isParameterArray);
    static int FindExactMatch(array<Type^>^ rubyParameterTypes, array<array<Type^>^>^ methodSignatures);

  public:
    static int GetMethodTableIndex(int methodId, int argc, VALUE *args);
  };
}