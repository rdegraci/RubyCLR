#include "stdafx.h"
#include "RubyHelpers.h"

namespace RubyClr {
  String^ Ruby::StripCharactersAfter(String^ string, wchar_t delimiter) {
    return string->Substring(0, string->IndexOf(delimiter));
  }

  String^ Ruby::ArrayToRubyShadowClassName(Type^ type) {
    String^ fullName = StripCharactersAfter(type->FullName, '[');
    return String::Format("{0}_array_{1}", fullName, type->GetArrayRank());
  }

  String^ Ruby::GenericToRubyShadowClassName(Type^ type) {
    List<String^>^ typeNames = gcnew List<String^>();
    String^ name = StripCharactersAfter(type->Name, '`');
    array<Type^>^ args = type->GetGenericArguments();
    for each (Type^ arg in args)
      typeNames->Add(arg->Name);
    return String::Format("{0}.{1}_generic_{2}", type->Namespace, name, String::Join("_", typeNames->ToArray()));
  }

  String^ Ruby::ConvertTypeNameToRubySymbolName(String^ typeName) {
    return typeName->Replace(".", "::")->Replace("+", "::");
  }

  // This is a very grotesque hack / thunk to workaround reflection emit call generation bug in dynamic assemblies / modules
  VALUE Ruby::CallRubyMethod(VALUE target, ID method_name, array<VALUE>^ parameters) {
    int parameter_count = parameters->Length;
    VALUE* params = new VALUE[parameter_count];
    try {
      for (int i = 0; i < parameter_count; ++i)
        params[i] = parameters[i];

      return rb_funcall2(target, method_name, parameter_count, params);
    }
    finally {
      if (params != 0) delete params;
    }
  }

  VALUE Ruby::ToRubyString(String^ string) {
    if (string == nullptr) return Qnil;
    IntPtr ptr;
    try {
      ptr    = System::Runtime::InteropServices::Marshal::StringToHGlobalAnsi(string);
      return rb_str_new2((char*)(void*)ptr);
    }
    finally {
      System::Runtime::InteropServices::Marshal::FreeHGlobal(ptr);
    }
  }

  VALUE Ruby::EvalString(String^ expression) {
    IntPtr str = System::Runtime::InteropServices::Marshal::StringToHGlobalAnsi(expression);
    VALUE result = rb_eval_string((const char *)(void*)str);
    System::Runtime::InteropServices::Marshal::FreeHGlobal(str);
    return result;
  }

  void Ruby::RaiseRubyException(VALUE exceptionType, String^ formatString, ... array<String^>^ params) {
    String^ message = String::Format(formatString, params);
    rb_raise(exceptionType, STR2CSTR(ToRubyString(message)));
  }

  String^ Ruby::TypeArrayToString(array<Type^>^ types) {
    List<String^>^ typeNames = gcnew List<String^>(types->Length);
    for each (Type^ type in types)
      typeNames->Add(type->FullName);
    return String::Join(",", typeNames->ToArray());
  }

  String^ Ruby::TypeToRubyShadowClassName(Type^ type) {
    String^ typeName = type->FullName;

    if (type->IsArray) 
      typeName = ArrayToRubyShadowClassName(type);
    else if (type->IsGenericType) 
      typeName = GenericToRubyShadowClassName(type);
    else {
      // Map runtime type names to non-runtime type names
      if (typeName == "System.RuntimeType")                    typeName = "System.Type";
      if (typeName == "System.Reflection.RuntimeMethodInfo")   typeName = "System.Reflection.MethodInfo";
      if (typeName == "System.Reflection.RtFieldInfo")         typeName = "System.Reflection.FieldInfo";
      if (typeName == "System.Reflection.RuntimePropertyInfo") typeName = "System.Reflection.PropertyInfo";
      if (typeName == "System.Reflection.RuntimeEventInfo")    typeName = "System.Reflection.EventInfo";
    }

    return ConvertTypeNameToRubySymbolName(typeName);
  }
}