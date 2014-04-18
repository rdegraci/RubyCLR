#pragma once

namespace RubyClr {
  // Required to shut up compiler for my usage within a C method - bug reported to MSFT - to see bug comment out next line
  public ref class HACKHACK {
    static List<Delegate^>^ DelegateReferences = gcnew List<Delegate^>();
    static KeyValuePair<String^, VALUE>^ Hack2 = gcnew KeyValuePair<String^, VALUE>;
  };

  public ref class Ruby {
    static String^ StripCharactersAfter(String^ string, wchar_t delimiter);
    static String^ ArrayToRubyShadowClassName(Type^ type);
    static String^ GenericToRubyShadowClassName(Type^ type);
    static String^ ConvertTypeNameToRubySymbolName(String^ typeName);

  public:
    // This is a very grotesque hack / thunk to workaround reflection emit varargs generation bug
    static VALUE CallRubyMethod(VALUE target, ID method_name, array<VALUE>^ parameters);
    static VALUE ToRubyString(String^ string);
    static VALUE EvalString(String^ expression);
    static void RaiseRubyException(VALUE exceptionType, String^ formatString, ... array<String^>^ params);\
    static String^ TypeArrayToString(array<Type^>^ types);
    static String^ TypeToRubyShadowClassName(Type^ type);
  };
}