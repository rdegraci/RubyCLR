// This file contains the managed and unmanaged Reflection API
// Some of these methods are callable from higher-level bridge
// code that already understands how to call managed types. 
// This file also contains all of the C-based reflection wrappers
// that are required by the lower levels of RbDynamicMethod

#pragma once
#pragma warning(disable:4947)

namespace RubyClr {
  ref class Finder {
  internal:
    static array<String^>^ SmartSplit(String^ typeList) {
      List<String^>^ types = gcnew List<String^>();
      int rank = 0, start = 0;
      for(int i = 0; i < typeList->Length; ++i) {
        wchar_t current = typeList[i];
        switch (current) {
          case '<':
          case '[': ++rank; 
                    break;
          case '>': 
          case ']': --rank; 
                    break;
          case ',': if (rank == 0) {
                      types->Add(typeList->Substring(start, i - start));
                      start = i + 1;
                    }
                    break;
        }
      }
      types->Add(typeList->Substring(start, typeList->Length - start));
      return types->ToArray();
    }

    static Regex^ re = gcnew Regex("^([^\\<]*)(\\<(.*)\\>)?$", RegexOptions::Compiled);

    static String^ ParseTypeRef(String^ type, ArrayList^ namespaces) {
      Match^ m = re->Match(type);
      String^ typeName = m->Groups[1]->Value;
      String^ types    = m->Groups[3]->Value;

      if (types == String::Empty) return typeName;

      array<String^>^ typeNames = SmartSplit(types); 
      int length                = typeNames->Length;
      for (int i = 0; i < length; ++i)
        typeNames[i] = InternalFindType(typeNames[i], namespaces)->FullName;

      return String::Format("{0}`{1}[{2}]", typeName, length, String::Join(", ", typeNames));
    }

    static Dictionary<String^, Type^>^ lookup = gcnew Dictionary<String^, Type^>();

    static Type^ FindTypeInAssembly(Assembly^ a, String^ typeName) {
      PerformanceCounters::IncrementTypeLookups();

      if (lookup->ContainsKey(typeName)) {
        PerformanceCounters::IncrementTypeLookupCacheHits();
        return lookup[typeName];
      }

      Type^ t = a->GetType(typeName, false, true); // ignore case!
      if (t != nullptr) {
        PerformanceCounters::IncrementTypeLookupCacheItems();
        lookup->Add(typeName, t);
      }
      return t;
    }

    static Type^ InternalFindType(String^ typeName, ArrayList^ namespaces) {
      if (typeName == "VALUE") return UInt32::typeid; // special case

      typeName = ParseTypeRef(typeName, namespaces);
      array<Assembly^>^ assemblies = System::AppDomain::CurrentDomain->GetAssemblies();
      for (int i = 0; i < assemblies->Length; ++i) {
        Type^ t = FindTypeInAssembly(assemblies[i], typeName);
        if (t != nullptr) return t;
        if (namespaces != nullptr) {
          for (int j = 0; j < namespaces->Count; ++j) {
            t = FindTypeInAssembly(assemblies[i], namespaces[j] + "." + typeName);
            if (t != nullptr) return t;
          }
        }
      }
      return nullptr;
    }
  };

  ref class Reflector {
  internal:
    static array<Type^>^ GetParameterTypes(array<ParameterInfo^>^ parameters) {
      array<Type^>^ parameterTypes = gcnew array<Type^>(parameters->Length);
      for (int i = 0; i < parameters->Length; ++i)
        parameterTypes[i] = parameters[i]->ParameterType;
      return parameterTypes;
    }

    static Type^ FindType(String^ typeName, ArrayList^ namespaces) {
      Type^ type = Finder::InternalFindType(typeName, namespaces);
      if (type == nullptr) Ruby::RaiseRubyException(rb_eArgError, "Could not find type {0}", typeName);
      return type;
    }

    static Type^ FindType(String^ typeName) {
      return FindType(typeName, nullptr);
    }

    static array<Type^>^ FindTypes(String^ typeNames) {
      array<String^>^ types   = Finder::SmartSplit(typeNames);
      array<Type^>^ typeArray = gcnew array<Type^>(types->Length);
      for (int i = 0; i < types->Length; ++i)
        typeArray[i] = FindType(types[i]->Trim());
      return typeArray;
    }

    static VALUE CreateDynamicMethod(String^ methodName, String^ returnType, String^ methodParameters) {
      Module^ module        = Assembly::GetExecutingAssembly()->GetModules()[0];
      DynamicMethod^ method = gcnew DynamicMethod(methodName, FindType(returnType), FindTypes(methodParameters), module);
      return Marshal::ToRubyObjectByRefInternal(method);
    }

    static VALUE CreateInterfaceMethod(TypeBuilder^ typeBuilder, String^ methodName, String^ returnType, String^ methodParameters) {
      return Qnil;
    }

    static VALUE CreateEventDynamicMethod(Type^ type, String^ eventName) {
      EventInfo^ eventInfo     = type->GetEvent(eventName);
      if (eventInfo == nullptr) throw gcnew Exception("Attempt to bind to non-existent event: " + eventName);
      MethodInfo^ invokeMethod = eventInfo->EventHandlerType->GetMethod("Invoke");
      Module^ module           = Assembly::GetExecutingAssembly()->GetModules()[0];
      array<Type^>^ paramTypes = GetParameterTypes(invokeMethod->GetParameters());
      DynamicMethod^ method    = gcnew DynamicMethod(String::Empty, invokeMethod->ReturnType, paramTypes, module);

      return Marshal::ToRubyObjectByRefInternal(method);
    }

    static VALUE DefineDynamicMethod(Type^ type, DynamicMethod^ dynamicMethod, String^ eventName, Object^ target) {
      EventInfo^ eventInfo  = type->GetEvent(eventName);
      eventInfo->AddEventHandler(target, dynamicMethod->CreateDelegate(eventInfo->EventHandlerType));
      return Qnil;
    }

    static OpCode GetOpCode(VALUE op_code) {
      BindingFlags flags = BindingFlags::IgnoreCase | BindingFlags::Static | BindingFlags::Public;
      String^ opCode = Marshal::ToClrString(op_code);
      if (opCode == "throw_ex") opCode = "throw";  // Workaround since throw is a Ruby keyword
      return (OpCode)OpCodes::typeid->GetField(opCode, flags)->GetValue(nullptr);
    }
  };

  // TODO: Change this back into a class that wraps static methods - too inefficient to gcnew a new object
  // for every instruction generated
  public ref class Generator {
    ILGenerator^ _generator;
    ArrayList^   _namespaces;

    MethodInfo^ FindGlobalMethod(String^ methodName) {
      Module^ module = Assembly::GetExecutingAssembly()->GetModules()[0];
      return module->GetMethod(methodName);
    }

    array<Type^>^ GetTypeArrayFromRubyTypeString(String^ typesString, ArrayList^ namespaces) {
      if (typesString == String::Empty) return gcnew array<Type^>(0);
      array<String^>^ types = Finder::SmartSplit(typesString);
      array<Type^>^   typeArray = gcnew array<Type^>(types->Length);
      for (int i = 0; i < types->Length; ++i)
        typeArray[i] = Finder::InternalFindType(types[i]->Trim(), namespaces);
      return typeArray;
    }

    MethodInfo^ FindGenericMethodTemplate(Type^ type, String^ methodName, array<Type^>^ paramTypes) {
      array<MethodInfo^>^ methods = type->GetMethods();
      MethodInfo^ method = nullptr;
      for (int i = 0; i < methods->Length; ++i) {
        array<ParameterInfo^>^ params = methods[i]->GetParameters();
        if (methods[i]->Name == methodName && params->Length == paramTypes->Length) {
          bool match = true;
          for (int j = 0; j < params->Length; ++j) {
            if (params[j]->ParameterType->IsGenericParameter) continue;
            if (params[j]->ParameterType == paramTypes[j]) continue;
            match = false;
            break;
          }
          if (match) {
            if (method == nullptr)
              method = methods[i];
            else
              Ruby::RaiseRubyException(rb_eArgError, "Found more than one method named {0} that matches signature {1} on type {2}.",
                methodName, Ruby::TypeArrayToString(paramTypes), type->FullName);
          }
        }
      }
      return method;
    }

    MethodInfo^ FindMethod(String^ typeName, String^ methodName, String^ methodTypes, String^ methodParameters, bool isStatic) {
      if (typeName == String::Empty) return FindGlobalMethod(methodName);

      Type^ type               = Reflector::FindType(typeName, _namespaces);
      array<Type^>^ paramTypes = GetTypeArrayFromRubyTypeString(methodParameters, _namespaces);
      MethodInfo^ method       = nullptr;

      BindingFlags flags = (isStatic ? BindingFlags::Static : BindingFlags::Instance) | BindingFlags::Public; 

      if (methodTypes == String::Empty) 
        method = type->GetMethod(methodName, flags, nullptr, paramTypes, nullptr);
      else {
        array<Type^>^ methodTypesArray = GetTypeArrayFromRubyTypeString(methodTypes, _namespaces);
        method = FindGenericMethodTemplate(type, methodName, paramTypes)->MakeGenericMethod(methodTypesArray);
      }

      if (method == nullptr) Ruby::RaiseRubyException(rb_eRuntimeError, "Cannot find method {0}::{1}<{2}>({3})", 
                                                      typeName, methodName, methodTypes, methodParameters);
      return method;
    }

    ConstructorInfo^ FindConstructor(String^ typeName, String^ ctorParameters) {
      Type^ type         = Reflector::FindType(typeName, _namespaces);
      BindingFlags flags = BindingFlags::Instance | BindingFlags::Public;
      return type->GetConstructor(flags, nullptr, GetTypeArrayFromRubyTypeString(ctorParameters, _namespaces), nullptr);     
    }

    FieldInfo^ FindField(String^ typeName, String^ fieldName, bool isStatic) {
      Type^ type         = Reflector::FindType(typeName, _namespaces);
      BindingFlags flags = (isStatic ? BindingFlags::Static : BindingFlags::Instance) | BindingFlags::Public; 
      return type->GetField(fieldName, flags);
    }

  public:
    Generator(VALUE self) {
      if (self != Qnil) {
        _generator  = (ILGenerator^)Marshal::ToObjectInternal(rb_funcall(self, rb_intern("generator"), 0));
        _namespaces = (ArrayList^)Marshal::ToObjectInternal(rb_funcall(self, rb_intern("namespaces"), 0));
      }
    }

    void Emit(VALUE op_code) {
      _generator->Emit(Reflector::GetOpCode(op_code));
    }

    void EmitMethodRef(VALUE op_code, VALUE is_static, VALUE type_name, VALUE method_name, VALUE method_types, VALUE method_parameters) {
      String^ typeName         = Marshal::ToClrString(type_name);
      String^ methodName       = Marshal::ToClrString(method_name);
      String^ methodTypes      = method_types == Qnil ? String::Empty : Marshal::ToClrString(method_types);
      String^ methodParameters = Marshal::ToClrString(method_parameters);
      bool isStatic            = is_static == Qtrue ? true : false;
      
      MethodInfo^ m = FindMethod(typeName, methodName, methodTypes, methodParameters, isStatic);
      _generator->Emit(Reflector::GetOpCode(op_code), m);
    }

    void EmitConstructorRef(VALUE op_code, VALUE type_name, VALUE ctor_parameters) {
      String^ typeName         = Marshal::ToClrString(type_name);
      String^ ctorParameters = Marshal::ToClrString(ctor_parameters);

      ConstructorInfo^ c = FindConstructor(typeName, ctorParameters);
      _generator->Emit(Reflector::GetOpCode(op_code), c);
    }

    void EmitFieldRef(VALUE op_code, VALUE is_static, VALUE type_name, VALUE field_name) {
      String^ typeName  = Marshal::ToClrString(type_name);
      String^ fieldName = Marshal::ToClrString(field_name);
      bool isStatic     = is_static == Qtrue ? true : false;

      FieldInfo^ f = FindField(typeName, fieldName, isStatic);
      _generator->Emit(Reflector::GetOpCode(op_code), f);
    }
  };

  public ref class MemberRef {
  protected:
    array<array<Type^>^>^ methodTable_;
    array<Type^>^         returnTypes_;

    void InitializeMethodTable(array<MemberInfo^>^ methods, bool isConstructor) {
      methodTable_ = gcnew array<array<Type^>^>(methods->Length);
      returnTypes_ = gcnew array<Type^>(methods->Length);

      for (int i = 0; i < methods->Length; ++i) {
        methodTable_[i] = Reflector::GetParameterTypes(((MethodBase^)methods[i])->GetParameters());
        returnTypes_[i] = isConstructor ? System::Void::typeid : ((MethodInfo^)methods[i])->ReturnType;
      }
    }
  public:
    property array<array<Type^>^>^ MethodTable {
      array<array<Type^>^>^ get() { return methodTable_; }
    };
  };

  public ref class MethodRef : MemberRef {
  public:
    MethodRef(array<MemberInfo^>^ methods) {
      InitializeMethodTable(methods, false);
    }

    property array<Type^>^ ReturnTypes {
      array<Type^>^ get() { return returnTypes_; }
    }
  };

  public ref class ConstructorRef : MemberRef {
  public:
    ConstructorRef(Type^ type) {
      InitializeMethodTable(type->GetConstructors(), true);
    }
  };

  public ref class MetadataCache {
    static List<MemberRef^>^ cache_ = gcnew List<MemberRef^>();
  public:
    static int Add(MemberRef^ member) {
      cache_->Add(member);
      return cache_->Count - 1;
    }

    static property MemberRef^ Item[int] {
      MemberRef^ get(int index) {
        return cache_[index];
      }
    };
  };

  ref class RubyAssembly {
    static VALUE GetTypeNames(Assembly^ assembly) {
      return GetTypeNames(assembly, rb_ary_new());
    }

    static VALUE GetTypeNames(Assembly^ assembly, VALUE type_names) {
      array<Type^>^ types = assembly->GetTypes();
      for each(Type^ type in types)
        rb_ary_push(type_names, Marshal::ToRubyString(type->FullName));
      return type_names;
    }
  public:
    static VALUE GetTypeNamesFromAssemblyName(VALUE assembly_name) {
      Assembly^ assembly = Assembly::LoadWithPartialName(Marshal::ToClrString(assembly_name));
      if (assembly == nullptr) rb_raise(rb_eArgError, "%s is not a valid assembly name", STR2CSTR(assembly_name));
      return GetTypeNames(assembly);
    }

    static VALUE GetTypeNamesFromAssemblyPath(VALUE assembly_path) {
      Assembly^ assembly = Assembly::LoadFrom(Marshal::ToClrString(assembly_path));
      if (assembly == nullptr) rb_raise(rb_eArgError, "Could not load assembly from %s", STR2CSTR(assembly_path));
      return GetTypeNames(assembly);
    }

    static VALUE GetTypeNamesFromLoadedAssemblies() {
      VALUE type_names             = rb_ary_new();
      array<Assembly^>^ assemblies = System::AppDomain::CurrentDomain->GetAssemblies();
      for each (Assembly^ assembly in assemblies)
        GetTypeNames(assembly, type_names);
      return type_names;
    }

    static VALUE GetTypesInAssembly(VALUE assemblyRef) {
      VALUE type_names   = rb_ary_new();
      Assembly^ assembly = (Assembly^)Marshal::ToObjectInternal(assemblyRef);
      GetTypeNames(assembly, type_names);
      return type_names;
    }

    static VALUE GetNamesOfLoadedAssemblies() {
      VALUE assembly_names = rb_ary_new();
      array<Assembly^>^ assemblies = System::AppDomain::CurrentDomain->GetAssemblies();
      for each (Assembly^ assembly in assemblies)
        rb_ary_push(assembly_names, Marshal::ToRubyString(assembly->GetName()->Name));
      return assembly_names;
    }
  };

  ref class RubyMemberInfo {
    array<MemberInfo^>^ _members;
  public:
    RubyMemberInfo(Type^ type, VALUE member_name, VALUE ruby_member_name, bool isStatic) {
      ClrTypeName               = Marshal::ToRubyString(type->FullName);
      String^ memberName        = Marshal::ToClrString(member_name);
      String^ rubyMemberName    = Marshal::ToClrString(ruby_member_name);
      IsIndexer                 = rubyMemberName->StartsWith("[]");
      IsSetter                  = rubyMemberName->EndsWith("=");
      if (IsSetter)  memberName = memberName->Substring(0, memberName->Length - 1);
      if (IsIndexer) memberName = type->IsArray ? (IsSetter ? "Set" : "Get") : "Item";
      RubyMemberName            = ruby_member_name;
      MemberName                = Marshal::ToRubyString(memberName);

      BindingFlags flags        = BindingFlags::Public | (isStatic ? BindingFlags::Static : BindingFlags::Instance);
      _members                  = type->GetMember(memberName, flags);
    }

    property array<MemberInfo^>^ Members {
      array<MemberInfo^>^ get() { return _members; }
    }

    bool IsIndexer;
    bool IsSetter;
    VALUE MemberId;
    VALUE ReturnTypes;
    VALUE Signatures;
    VALUE MemberType;
    VALUE MemberName;
    VALUE RubyMemberName;
    VALUE ClrTypeName;
    VALUE IsVirtual;
    VALUE ClassThatDefinesMember;

    VALUE ToMemberInfo() {
      VALUE memberInfoClass = rb_const_get(rb_cObject, rb_intern("MemberInfo"));
      return rb_funcall(memberInfoClass, rb_intern("new"), 9, MemberId, MemberType, MemberName, ReturnTypes, ClrTypeName, 
                        RubyMemberName, Signatures, IsVirtual, ClassThatDefinesMember);
    }
  };

  ref class RubyType {
    Type^ _type;

    // TODO: refactor these methods out of here - am duplicating right in core.h now
    VALUE CreateSignature(array<Type^>^ signature) {
      if (signature == nullptr) return Qnil;
      VALUE signature_array = rb_ary_new2(signature->Length);
      for each (Type^ parameterType in signature) {
        VALUE parameter_type_name = Marshal::ToRubyString(parameterType->FullName);
        rb_ary_push(signature_array, parameter_type_name);
      }
      return signature_array;
    }

    VALUE CreateSignatureArray(array<array<Type^>^>^ methodTable) {
      if (methodTable == nullptr) return Qnil;
      VALUE signatures = rb_ary_new2(methodTable->Length);
      for each (array<Type^>^ signature in methodTable)
        rb_ary_push(signatures, CreateSignature(signature));
      return signatures;
    }

    VALUE CreateSignatureArray(array<ParameterInfo^>^ parameters) {
      VALUE signatures = rb_ary_new();
      rb_ary_push(signatures, CreateSignature(Reflector::GetParameterTypes(parameters)));
      return signatures;
    }

    VALUE CreateIsVirtualArray(array<MemberInfo^>^ members) {
      VALUE result = rb_ary_new2(members->Length);
      for each (MethodInfo^ method in members)
        rb_ary_push(result, method->IsVirtual ? Qtrue : Qfalse);
      return result;
    }

    Type^ GetMemberType(RubyMemberInfo^ members, int index) {
      Type^ baseMemberType = members->Members[index]->GetType()->BaseType;

      // Workaround for the fact that FieldInfo -> RuntimeFieldInfo -> RtFieldInfo!
      if (baseMemberType->FullName == "System.Reflection.RuntimeFieldInfo") baseMemberType = baseMemberType->BaseType;
      return baseMemberType;
    }

    RubyMemberInfo^ GetMembers(VALUE camel_case_name, VALUE literal_name, bool isStatic) {
      RubyMemberInfo^ rubyMemberInfo = gcnew RubyMemberInfo(_type, literal_name, literal_name, isStatic);
      if (rubyMemberInfo->Members->Length == 0) {
        rubyMemberInfo = gcnew RubyMemberInfo(_type, camel_case_name, literal_name, isStatic);
        if (rubyMemberInfo->Members->Length == 0) {
          VALUE type_name = Marshal::ToRubyString(_type->FullName);
          rb_raise(rb_eRuntimeError, "Member %s not found in type %s", STR2CSTR(literal_name), STR2CSTR(type_name));
        }
      }
      return rubyMemberInfo;
    }

    VALUE GetArrayInfo(RubyMemberInfo^ members) {
      MethodRef^ methodRef = gcnew MethodRef(members->Members);
      members->Signatures  = CreateSignatureArray(methodRef->MethodTable);
      members->ReturnTypes = CreateSignature(methodRef->ReturnTypes);
      members->IsVirtual   = CreateIsVirtualArray(members->Members);
      members->MemberType  = rb_str_new2("array");
      return members->ToMemberInfo();
    }

    VALUE GetPropertyInfo(RubyMemberInfo^ members) {
      List<MethodInfo^>^ methodInfos = gcnew List<MethodInfo^>();
      for each (PropertyInfo^ propertyInfo in members->Members) {
        MethodInfo^ methodInfo = members->IsSetter ? propertyInfo->GetSetMethod() : propertyInfo->GetGetMethod();
        if (methodInfo != nullptr) methodInfos->Add(methodInfo);
      }

      array<MethodInfo^>^ methodInfosArray = methodInfos->ToArray();

      String^ memberName   = Marshal::ToClrString(members->MemberName);
      MethodRef^ methodRef = gcnew MethodRef(methodInfosArray);
      members->MemberType  = methodInfos->Count == 1 ? rb_str_new2("fastproperty") : rb_str_new2("property");
      members->MemberName  = Marshal::ToRubyString(members->IsSetter ? "set_" + memberName : "get_" + memberName);
      members->ReturnTypes = CreateSignature(methodRef->ReturnTypes);
      members->IsVirtual   = CreateIsVirtualArray(methodInfosArray);
      members->Signatures  = CreateSignatureArray(methodRef->MethodTable);
      members->MemberId    = INT2FIX(-1);
      if (members->Members->Length != 1) 
        members->MemberId = INT2FIX(MetadataCache::Add(methodRef));
      return members->ToMemberInfo();
    }

    VALUE GetFieldInfo(RubyMemberInfo^ members, int index) {
      FieldInfo^ fieldInfo = (FieldInfo^)members->Members[index];
      members->MemberType  = rb_str_new2("field");
      members->ReturnTypes = CreateSignature(gcnew array<Type^> { fieldInfo->FieldType });
      return members->ToMemberInfo();
    }

    VALUE GetEventInfo(RubyMemberInfo^ members, int index) {
      EventInfo^ eventInfo     = (EventInfo^)members->Members[index];
      MethodInfo^ invokeMethod = eventInfo->EventHandlerType->GetMethod("Invoke");
      members->MemberType      = rb_str_new2("event");
      members->Signatures      = CreateSignatureArray(invokeMethod->GetParameters());
      members->ReturnTypes     = CreateSignature(gcnew array<Type^> { invokeMethod->ReturnType });
      return members->ToMemberInfo();
    }

    VALUE GetMethodInfo(RubyMemberInfo^ members) {
      MethodRef^ methodRef = gcnew MethodRef(members->Members);
      members->ReturnTypes = CreateSignature(methodRef->ReturnTypes);
      members->MemberType  = members->Members->Length == 1 ? rb_str_new2("fastmethod") : rb_str_new2("method");
      members->Signatures  = CreateSignatureArray(methodRef->MethodTable);
      members->IsVirtual   = CreateIsVirtualArray(members->Members);
      members->MemberId    = INT2FIX(-1);
      if (members->Members->Length != 1) 
        members->MemberId  = INT2FIX(MetadataCache::Add(methodRef));
      return members->ToMemberInfo();
    }

    int GetMemberTypeIndex(RubyMemberInfo^ members, Type^ memberType) {
      for (int i = 0; i < members->Members->Length; ++i) 
        if (GetMemberType(members, i) == memberType) 
          return i;
      return -1;
    }

    VALUE GetMemberInfo(VALUE camel_case_name, VALUE literal_name, bool isStatic, VALUE block_given) {
      RubyMemberInfo^ members = GetMembers(camel_case_name, literal_name, isStatic);

      int eventInfoIndex = GetMemberTypeIndex(members, EventInfo::typeid);
      if (eventInfoIndex == -1) {
        Type^ baseMemberType = GetMemberType(members, 0);

        if (_type->IsArray && members->IsIndexer)
          return GetArrayInfo(members);
        else if (baseMemberType == PropertyInfo::typeid)
          return GetPropertyInfo(members);
        else if (baseMemberType == FieldInfo::typeid) 
          return GetFieldInfo(members, 0);
        else if (baseMemberType == EventInfo::typeid)
          return GetEventInfo(members, 0);
        else if (baseMemberType == MethodInfo::typeid)
          return GetMethodInfo(members);
        
        rb_raise(rb_eArgError, "Unknown member info type. This should be impossible");
      }
      else {
        if (block_given == Qtrue) {
          return GetEventInfo(members, eventInfoIndex);
        }
        else {
          int fieldInfoIndex = GetMemberTypeIndex(members, FieldInfo::typeid);
          if (fieldInfoIndex == -1) rb_raise(rb_eArgError, "Trying to reference a field using a block. This is only legal for events.");
          return GetFieldInfo(members, fieldInfoIndex);
        }
      }
    }

  public:
    RubyType(VALUE klass) {
      _type = (Type^)Marshal::ToObjectInternal(rb_iv_get(klass, "@clr_type"));
    }

    VALUE GetRubyShadowClass() {
      VALUE class_object = Marshal::GetRubyClassObject(Type::typeid);
      return Marshal::ToRubyObjectByRef(class_object, _type);
    }

    VALUE GetEnumValues() {
      if (!_type->IsEnum) throw gcnew Exception("GetEnumValues can only be called on enumerations.");

      VALUE values = rb_ary_new();
      for each(int enumValue in Enum::GetValues(_type))
        rb_ary_push(values, Marshal::ToRubyNumber(enumValue));
      return values;
    }

    VALUE GetEnumNames() {
      if (!_type->IsEnum) throw gcnew Exception("GetEnumNames can only be called on enumerations.");

      VALUE names = rb_ary_new();
      for each(String^ enumName in Enum::GetNames(_type))
        rb_ary_push(names, Marshal::ToRubyString(enumName));
      return names;
    }

    VALUE GetConstructorInfo() {
      ConstructorRef^ constructorRef = gcnew ConstructorRef(_type);
      VALUE signatures               = CreateSignatureArray(constructorRef->MethodTable);
      VALUE clr_type                 = Marshal::ToRubyString(_type->FullName);
      VALUE member_type              = constructorRef->MethodTable->Length == 1 ? rb_str_new2("fastctor") : rb_str_new2("ctor");
      VALUE member_id                = INT2FIX(-1);
      if (constructorRef->MethodTable->Length != 1) 
        member_id = INT2FIX(MetadataCache::Add(constructorRef));

      VALUE ctor_info_class = rb_const_get(rb_cObject, rb_intern("ConstructorInfo"));
      return rb_funcall(ctor_info_class, rb_intern("new"), 4, member_id, member_type, clr_type, signatures);
    }

    VALUE GetInstanceMemberInfo(VALUE camel_case_name, VALUE literal_name, VALUE block_given) {
      return GetMemberInfo(camel_case_name, literal_name, false, block_given);
    }

    VALUE GetStaticMemberInfo(VALUE camel_case_name, VALUE literal_name, VALUE block_given) {
      return GetMemberInfo(camel_case_name, literal_name, true, block_given);
    }
  };
}