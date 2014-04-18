#include "stdafx.h"
#include "RubyHelpers.h"
#include "PerfCounters.h"
#include "Marshal.h"
#include "Reflection.h"
#include "Utility.h"

namespace RubyClr {
  VALUE Identity::GetProxyObject(int hashCode) {
    VALUE hash_code = Marshal::ToRubyNumber(hashCode);
    VALUE has_key   = rb_funcall(g_ruby_identity_map, rb_intern("has_key?"), 1, hash_code);

    return has_key == Qtrue ? rb_funcall(g_ruby_identity_map, rb_intern("[]"), 1, hash_code) : Qnil;
  }

  void Identity::CacheProxyObject(int hashCode, VALUE proxyObject) {
    VALUE hash_code = Marshal::ToRubyNumber(hashCode);
    VALUE has_key   = rb_funcall(g_ruby_identity_map, rb_intern("has_key?"), 1, hash_code);

    // This really should be impossible since we don't cache value types -- but I would like to get some opinions on the corner cases to consider here.
    if (hash_code == Qtrue)
      throw gcnew Exception("Adding a duplicate proxy object to identity cache - this should be impossible");

    rb_funcall(g_ruby_identity_map, rb_intern("[]="), 2, hash_code, proxyObject);
  }

  void Identity::RemoveProxyObject(int hashCode) {
    rb_funcall(g_ruby_identity_map, rb_intern("delete"), 1, Marshal::ToRubyNumber(hashCode));
  }

  /*
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
  */

  Object^ DynamicCode::BoxValueType(VALUE value) {
    if (_boxValueTypeMethod == nullptr) {
      Module^ module        = Assembly::GetExecutingAssembly()->GetModules()[0];
      DynamicMethod^ method = gcnew DynamicMethod(String::Empty, Object::typeid, gcnew array<Type^> { Type::typeid, VALUE::typeid, Int32::typeid }, module);
      ILGenerator^ g        = method->GetILGenerator();

      MethodInfo^ createInstanceMethod = Activator::typeid->GetMethod("CreateInstance", gcnew array<Type^> { Type::typeid });
      LocalBuilder^ objref = g->DeclareLocal(Object::typeid);

      // Create a boxed value type object of the type passed in
      g->Emit(OpCodes::Ldarg_0);  
      g->Emit(OpCodes::Call, createInstanceMethod);
      g->Emit(OpCodes::Stloc_S, objref);

      // Cpblk can take an object reference as a parameter??? This doesn't work.
      g->Emit(OpCodes::Ldloc_S, objref);

      // Load the source address and get what's pointed to by the data field of the struct
      g->Emit(OpCodes::Ldarg_1); 
      g->Emit(OpCodes::Ldc_I4_S, 16);
      g->Emit(OpCodes::Add);                
      g->Emit(OpCodes::Ldind_I4);

      // Load the number of bytes to copy
      g->Emit(OpCodes::Ldarg_2);            
      g->Emit(OpCodes::Cpblk);

      g->Emit(OpCodes::Ldloc_S, objref);
      g->Emit(OpCodes::Ret);

      _boxValueTypeMethod = (ValueTypeMarshalerEventHandler^)method->CreateDelegate(ValueTypeMarshalerEventHandler::typeid);
    }

    VALUE klass = rb_class_of(value);
    int size    = FIX2INT(rb_iv_get(klass, "@value_type_size"));
    Type^ type  = (Type^)Marshal::ToObjectInternal(rb_iv_get(klass, "@clr_type"));
    
    return _boxValueTypeMethod(type, value, size);
  }

  System::Reflection::Emit::Label LabelDictionary::GetOrCreateLabel(ILGenerator^ g, VALUE label_name) {
    System::Reflection::Emit::Label label;
    String^ labelName = Marshal::ToClrString(label_name);
    if (!ContainsKey(labelName)) {
      label = g->DefineLabel();
      this[labelName] = label;
    }
    else
      label = this[labelName];
    return label;
  }

  VALUE CodeGenerator::CreateNamespaceList() {
    ArrayList^ namespaces = gcnew ArrayList();
    namespaces->Add("System");
    namespaces->Add("RubyClr");
    return Marshal::ToRubyObjectByRefInternal(namespaces);
  }

  VALUE CodeGenerator::CreateGenerator(VALUE generator, VALUE ruby_obj_field, VALUE method_name) {
    return rb_funcall(g_generator, rb_intern("new"), 6, generator, 
      Marshal::ToRubyObjectByRefInternal(gcnew LabelDictionary()), 
      Marshal::ToRubyObjectByRefInternal(gcnew VariableDictionary()), 
      CreateNamespaceList(), 
      ruby_obj_field, method_name);
  }

  VALUE CodeGenerator::CreateGenerator(VALUE generator) {
    return CreateGenerator(generator, Qnil, Qnil);
  }

  // ClrShadowClass implementation
  // TODO: implement this method when I understand how to implement IDisposable in a derived class ..
  //ClrShadowClass::~ClrShadowClass() {
  //  this->!ClrShadowClass(); 
  //  GC::SuppressFinalize(this);
  //}

  ClrShadowClass::!ClrShadowClass() {
    if (ruby_obj_ref != Qnil) {
      VALUE object_id = rb_funcall(ruby_obj_ref, rb_intern("object_id"), 0);
      if (object_id != Qnil) {
        rb_funcall(g_ruby_object_handles, rb_intern("delete"), 1, object_id);
        ruby_obj_ref = Qnil;
      }
    }
  }

  String^ ClrShadowClass::ToString() {
    return Marshal::ToClrString(rb_funcall(ruby_obj_ref, rb_intern("to_s"), 0));
  }

  // ShadowClass implementation
  String^ ShadowClass::GetRandomName() {
    return "T" + Guid::NewGuid().ToString()->Substring(0, 8);
  }

  String^ ShadowClass::GetInterfaceName(VALUE itf) {
    VALUE itf_name = rb_funcall(itf, rb_intern("to_s"), 0);
    return Marshal::ToClrString(itf_name);
  }

  // TODO: next two methods are duplicated from RubyType. Need to refactor this stuff somewhere else
  VALUE ShadowClass::CreateSignature(array<Type^>^ signature) {
    if (signature == nullptr) return Qnil;
    VALUE signature_array = rb_ary_new2(signature->Length);
    for each (Type^ parameterType in signature) {
      VALUE parameter_type_name = Marshal::ToRubyString(parameterType->FullName);
      rb_ary_push(signature_array, parameter_type_name);
    }
    return signature_array;
  }

  VALUE ShadowClass::CreateSignatureArray(array<Type^>^ parameters) {
    VALUE signatures = rb_ary_new();
    rb_ary_push(signatures, CreateSignature(parameters));
    return signatures;
  }

  int ShadowClass::GetSizeOfValueTypeHack(Type^ type) {
    Module^ module        = Assembly::GetExecutingAssembly()->GetModules()[0];
    DynamicMethod^ method = gcnew DynamicMethod(String::Empty, int::typeid, gcnew array<Type^> {}, module);
    ILGenerator^ g        = method->GetILGenerator();
    g->Emit(OpCodes::Sizeof, type);
    g->Emit(OpCodes::Ret);

    SizeOfEventHandler^ del = (SizeOfEventHandler^)method->CreateDelegate(SizeOfEventHandler::typeid);
    return del->Invoke();
  }

  VALUE ShadowClass::CloneValueType(VALUE self) {
    VALUE clone       = rb_obj_clone(self);
    VALUE klass       = rb_class_of(self);
    int valueTypeSize = FIX2LONG(rb_iv_get(klass, "@value_type_size"));

    void *cloneData   = ruby_xmalloc(valueTypeSize);
    memcpy(cloneData, DATA_PTR(self), valueTypeSize);
    DATA_PTR(clone)   = cloneData;

    return clone;
  }

  VALUE ShadowClass::CreateRubyShadowClass(Type^ type, String^ typeName) {
    VALUE class_object;
    // TODO: think this through -- this is causing major instability in the bridge
    //if (type->BaseType != nullptr) {
    //  String^ baseClassName   = Ruby::TypeToRubyShadowClassName(type->BaseType);
    //  VALUE base_class_object = Ruby::EvalString(baseClassName);
    //  class_object = rb_funcall(rb_cClass, rb_intern("new"), 1, base_class_object);
    //}
    //else
      class_object = rb_funcall(rb_cClass, rb_intern("new"), 0);

    VALUE shim_refs = Marshal::ToRubyObjectByRefInternal(gcnew List<Delegate^>());
    rb_iv_set(class_object, "@shim_refs", shim_refs);

    rb_iv_set(class_object, "@clr_type",                   Marshal::ToRubyObjectByRefInternal(type));
    rb_iv_set(class_object, "@is_value_type",              type->IsValueType ? Qtrue : Qfalse);
    rb_iv_set(class_object, "@is_enum",                    type->IsEnum ? Qtrue : Qfalse);
    rb_iv_set(class_object, "@is_interface",               type->IsInterface ? Qtrue : Qfalse);
    rb_iv_set(class_object, "@is_generic",                 type->IsGenericType ? Qtrue : Qfalse);
    rb_iv_set(class_object, "@is_generic_type_definition", type->IsGenericTypeDefinition ? Qtrue : Qfalse);
    rb_iv_set(class_object, "@is_nested",                  type->IsNested ? Qtrue : Qfalse);
    rb_iv_set(class_object, "@event_refs",                 rb_ary_new());

    if (type->IsValueType) {
      int valueTypeSize = -1; 
      if (type->IsEnum)
        valueTypeSize = 4;
      else if (type->IsLayoutSequential || type->IsExplicitLayout)
        valueTypeSize = System::Runtime::InteropServices::Marshal::SizeOf(type);
      else if (type->IsAutoLayout)
        valueTypeSize = GetSizeOfValueTypeHack(type);

      rb_iv_set(class_object, "@value_type_size", INT2FIX(valueTypeSize));
      rb_define_method(class_object, "clone", RUBY_METHOD_FUNC(CloneValueType), 0);
    }

    rb_define_alloc_func(class_object, alloc_clr_object);
    
    // TODO: perhaps should move this cache add somewhere else?
    Marshal::TypeNameToClassObject.Add(typeName, class_object);

    rb_funcall(class_object, rb_intern("extend"), 1, rb_const_get(rb_cObject, rb_intern("ClrClassStaticMethods"))); 

    // Can I make this a generic extension thing in the future?
    if (!type->IsInterface) {
      if (System::Collections::IEnumerable::typeid->IsAssignableFrom(type))
        rb_funcall(class_object, rb_intern("include"), 1, rb_const_get(rb_cObject, rb_intern("ClrEnumerator")));

      // TODO: fix the bug with generic interfaces by fixing the way find_type works
      // need to truncate to root of generic interface (e.g. System.IComparable`1) and then expand by calling MakeGenericType
      // to find the correct type. I believe this should be a bug in lots of other areas too.
      //Type^ comparableType = get_icomparable_of_t(type);
      //if (comparableType != nullptr && comparableType->IsAssignableFrom(type))
      //  rb_funcall(class_object, rb_intern("include"), 1, rb_const_get(rb_cObject, rb_intern("ClrComparableOfT")));
      //else {
        Type^ comparableType = System::IComparable::typeid;
        if (comparableType != nullptr && comparableType->IsAssignableFrom(type))
          rb_funcall(class_object, rb_intern("include"), 1, rb_const_get(rb_cObject, rb_intern("ClrComparable")));
      //}
    }

    return class_object;
  }

  TypeBuilder^ ShadowClass::CreateAnonymousType() {
    AssemblyName^ assemblyName = gcnew AssemblyName(GetRandomName());
    AssemblyBuilder^ assemblyBuilder = AppDomain::CurrentDomain->DefineDynamicAssembly(assemblyName, AssemblyBuilderAccess::Run);
    array<AssemblyName^>^ refs = assemblyBuilder->GetReferencedAssemblies();

    ModuleBuilder^ moduleBuilder = assemblyBuilder->DefineDynamicModule(GetRandomName());
    TypeAttributes typeAttributes = TypeAttributes::Public | TypeAttributes::AutoLayout | TypeAttributes::BeforeFieldInit | TypeAttributes::AnsiClass;
    return moduleBuilder->DefineType(GetRandomName(), typeAttributes, ClrShadowClass::typeid);
  }

  FieldInfo^ ShadowClass::CreateConstructorAndField(TypeBuilder^ tb) {
    FieldInfo^ rubyObjRefField = tb->BaseType->GetField("ruby_obj_ref", BindingFlags::Instance | BindingFlags::NonPublic);

    ConstructorBuilder^ cb = tb->DefineConstructor(MethodAttributes::Public, CallingConventions::Standard, gcnew array<Type^> { VALUE::typeid });
    ILGenerator^ cg = cb->GetILGenerator();
    cg->Emit(OpCodes::Ldarg_0);
    cg->Emit(OpCodes::Ldarg_1);
    cg->Emit(OpCodes::Stfld, rubyObjRefField);
    cg->Emit(OpCodes::Ret);

    return rubyObjRefField;
  }

  ShadowClassDictionary^ ShadowClass::Cache::get() {
    return _cache;
  }

  String^ ShadowClass::ToCamelCase(VALUE attribute) {
    String^ name = Marshal::ToClrString(attribute);
    
    array<String^>^ fragments = name->Split('_');
    for (int i = 0; i < fragments->Length; ++i) {
      String^ fragment = fragments[i];
      if (fragment->Length > 0)
        fragments[i] = Char::ToUpper(fragment[0]) + fragment->Substring(1);
    }

    return String::Join(String::Empty, fragments);
  }

  MethodBuilder^ ShadowClass::GenerateMethod(TypeBuilder^ tb, FieldInfo^ rubyObjRefField, String^ methodName, MethodAttributes methodAttributes, String^ shimMethodName, Type^ returnType, array<Type^>^ parameterTypes, String^ memberType) {
    MethodBuilder^ mb = tb->DefineMethod(methodName, methodAttributes, returnType, parameterTypes);
    RubyMemberInfo^ mi = gcnew RubyMemberInfo(Int32::typeid, Marshal::ToRubyString(shimMethodName), 
      Marshal::ToRubyString(shimMethodName), false);

    mi->MemberType  = Marshal::ToRubyString(memberType);
    mi->Signatures  = CreateSignatureArray(parameterTypes);
    mi->ReturnTypes = CreateSignature(gcnew array<Type^> { returnType });

    ILGenerator^ g = mb->GetILGenerator();
    VALUE generator = CodeGenerator::CreateGenerator(Marshal::ToRubyObject(g), 
      Marshal::ToRubyObjectByRefInternal(rubyObjRefField), mi->ToMemberInfo());

    rb_funcall(rb_const_get(rb_cObject, rb_intern("RbDynamicMethod")), rb_intern("mixin"), 1, generator);
    rb_obj_instance_eval(0, 0, generator);

    return mb;
  }

  List<String^>^ ShadowClass::GenerateMethodExemptionList(Type^ itf) {
    List<String^>^ exemptedMethods = gcnew List<String^>();
    for each (EventInfo^ eventInfo in itf->GetEvents()) {
      exemptedMethods->Add(eventInfo->GetAddMethod()->Name);
      exemptedMethods->Add(eventInfo->GetRemoveMethod()->Name);
    }
    return exemptedMethods;
  }

  void ShadowClass::GenerateMethods(TypeBuilder^ tb, FieldInfo^ rubyObjRefField, Type^ itf) {
    List<String^>^ exemptedMethods = GenerateMethodExemptionList(itf);
    MethodAttributes methodAttributes = MethodAttributes::Public | MethodAttributes::Virtual | MethodAttributes::HideBySig;
    array<MethodInfo^>^ methods = itf->GetMethods();
    for each (MethodInfo^ method in methods) {
      if (!exemptedMethods->Contains(method->Name))
        GenerateMethod(tb, rubyObjRefField, method->Name, methodAttributes, method->Name, method->ReturnType, Reflector::GetParameterTypes(method->GetParameters()), "method");
    }
  }

  Type^ ShadowClass::GetAttributeType(VALUE obj, VALUE attribute_name) {
    // TODO: Should I avoid strongly-typed collections for ActiveRecord objects altogether? If not I run into hard interop problems with things like identity columns.
    return Object::typeid;

    //VALUE klass = rb_class_of(rb_funcall(obj, rb_intern(STR2CSTR(attribute_name)), 0));
    //String^ klassName = Marshal::ToClrString(rb_funcall(klass, rb_intern("name"), 0));

    //Type^ propertyType;
    //if (klassName == "Fixnum") 
    //  propertyType = Int32::typeid;
    //else if (klassName == "Float") 
    //  propertyType = Double::typeid;
    //else if (klassName == "String")
    //  propertyType = String::typeid;
    //else if (klassName == "Date") 
    //  propertyType = DateTime::typeid; // We are not auto-marshaling Date / Time to DateTime yet - we will
    //else 
    //  throw gcnew Exception("Unsupported property type for databinding");

//    return propertyType;

  }

  void ShadowClass::GenerateProperties(TypeBuilder^ tb, FieldInfo^ rubyObjRefField, VALUE obj) {
    if (rb_respond_to(obj, rb_intern("get_binding_context"))) {
      VALUE binding_context = rb_funcall(obj, rb_intern("get_binding_context"), 0);

      int length = FIX2INT(rb_funcall(binding_context, rb_intern("length"), 0));
      for (int i = 0; i < length; ++i) {
        VALUE attribute_name  = rb_funcall(binding_context, rb_intern("[]"), 1, INT2FIX(i));
        String^ attributeName = ToCamelCase(attribute_name);

        Type^ propertyType = GetAttributeType(obj, attribute_name);
        PropertyBuilder^ pb = tb->DefineProperty(attributeName, PropertyAttributes::None, propertyType, nullptr);
        String^ rubyAttributeMethodName = Marshal::ToClrString(attribute_name);

        MethodAttributes methodAttributes = MethodAttributes::Public | MethodAttributes::SpecialName | MethodAttributes::HideBySig;
        MethodBuilder^ getterMethod = GenerateMethod(tb, rubyObjRefField, "get_" + attributeName, methodAttributes, rubyAttributeMethodName, propertyType, Type::EmptyTypes, "property_get");
        MethodBuilder^ setterMethod = GenerateMethod(tb, rubyObjRefField, "set_" + attributeName, methodAttributes, rubyAttributeMethodName, void::typeid, gcnew array<Type^> { propertyType }, "property_set");
        
        pb->SetGetMethod(getterMethod);
        pb->SetSetMethod(setterMethod);
      }
    }
  }

  void ShadowClass::GenerateEvents(TypeBuilder^ tb, Type^ itf) {
    array<EventInfo^>^ events = itf->GetEvents();

    // Lookup up Delegate::Combine(Delegate, Delegate) and Delegate::Remove(Delegate, Delegate) methods
    MethodInfo^ combineMethod = Delegate::typeid->GetMethod("Combine", BindingFlags::Public | BindingFlags::Static, nullptr, gcnew array<Type^> { Delegate::typeid, Delegate::typeid }, nullptr);
    MethodInfo^ removeMethod  = Delegate::typeid->GetMethod("Remove", BindingFlags::Public | BindingFlags::Static, nullptr, gcnew array<Type^> { Delegate::typeid, Delegate::typeid }, nullptr);
    //MethodInfo^ writeMethod   = Console::typeid->GetMethod("WriteLine", BindingFlags::Public | BindingFlags::Static, nullptr, gcnew array<Type^> { Int32::typeid }, nullptr);
    //MethodInfo^ getHashCodeMethod = Console::typeid->GetMethod("GetHashCode", BindingFlags::Public | BindingFlags::Instance, nullptr, Type::EmptyTypes, nullptr);

    MethodAttributes attrs = MethodAttributes::Public | MethodAttributes::Virtual | MethodAttributes::SpecialName | MethodAttributes::Final | MethodAttributes::NewSlot | MethodAttributes::HideBySig;

    for each (EventInfo^ evt in events) {
      EventBuilder^ eb = tb->DefineEvent(evt->Name, evt->Attributes, evt->EventHandlerType);

      // Define event field - must be public 
      FieldBuilder^ field = tb->DefineField(evt->Name, evt->EventHandlerType, FieldAttributes::Public);

      // Define add method
      MethodBuilder^ addEventMethod = tb->DefineMethod(evt->GetAddMethod()->Name, attrs, void::typeid, gcnew array<Type^> { evt->EventHandlerType });
      ILGenerator^ g = addEventMethod->GetILGenerator();
      //g->Emit(OpCodes::Ldarg_0);
      //g->Emit(OpCodes::Callvirt, getHashCodeMethod);
      //g->Emit(OpCodes::Call, writeMethod);
      g->Emit(OpCodes::Ldarg_0);
      g->Emit(OpCodes::Ldarg_0);
      g->Emit(OpCodes::Ldfld, field);
      g->Emit(OpCodes::Ldarg_1);
      g->Emit(OpCodes::Call, combineMethod);
      g->Emit(OpCodes::Castclass, evt->EventHandlerType);
      g->Emit(OpCodes::Stfld, field);
      g->Emit(OpCodes::Ret);

      eb->SetAddOnMethod(addEventMethod);

      // Define remove method
      MethodBuilder^ removeEventMethod = tb->DefineMethod(evt->GetRemoveMethod()->Name, attrs, void::typeid, gcnew array<Type^> { evt->EventHandlerType });
      
      ILGenerator^ g2 = removeEventMethod->GetILGenerator();
      g2->Emit(OpCodes::Ldarg_0);
      g2->Emit(OpCodes::Ldarg_0);
      g2->Emit(OpCodes::Ldfld, field);
      g2->Emit(OpCodes::Ldarg_1);
      g2->Emit(OpCodes::Call, removeMethod);
      g2->Emit(OpCodes::Castclass, evt->EventHandlerType);
      g2->Emit(OpCodes::Stfld, field);
      g2->Emit(OpCodes::Ret);

      eb->SetRemoveOnMethod(removeEventMethod);
    }
  }

  Type^ ShadowClass::Create(VALUE obj) {
    VALUE interfaces = Qnil;
    if (rb_respond_to(obj, rb_intern("clr_interfaces")))
      interfaces = rb_funcall(obj, rb_intern("clr_interfaces"), 0);

    TypeBuilder^ tb  = CreateAnonymousType();
    FieldInfo^ rubyObjRefField = CreateConstructorAndField(tb);

    if (interfaces != Qnil) {
      int length = FIX2LONG(rb_funcall(interfaces, rb_intern("length"), 0));
      for (int i = 0; i < length; ++i) {
        VALUE itf = rb_funcall(interfaces, rb_intern("[]"), 1, INT2FIX(i));
        Type^ itfType = Reflector::FindType(GetInterfaceName(itf));
        tb->AddInterfaceImplementation(itfType);

        GenerateMethods(tb, rubyObjRefField, itfType);
        GenerateEvents(tb, itfType);
        
        for each (Type^ itf in itfType->GetInterfaces()) {
          GenerateMethods(tb, rubyObjRefField, itf);
          GenerateEvents(tb, itf);
        }
      }
    }

    GenerateProperties(tb, rubyObjRefField, obj);

    try {
      Type^ type = tb->CreateType();
      rb_funcall(rb_cObject, rb_intern("type_name_set"), 1, Marshal::ToRubyString(tb->Name));
      return type;
    }
    catch (Exception^ e) {
      Console::WriteLine("Exception {0}", e->Message);
      return nullptr;
    }
  }

  Type^ ShadowClass::CreateClrShadowClass(VALUE obj) {
    VALUE class_name = rb_funcall(rb_class_of(obj), rb_intern("name"), 0);
    String^ className = Marshal::ToClrString(class_name);
    if (ShadowClass::Cache->ContainsKey(className)) {
      return ShadowClass::Cache[className];
    }
    else {
      Type^ shadowClass = Create(obj);
      ShadowClass::Cache->Add(className, shadowClass);
      return shadowClass;
    }
  }

  Type^ RuntimeResolver::MapRubyTypeToDotNetType(VALUE object) {
    if (object == Qtrue || object == Qfalse)      return bool::typeid;
    if (TYPE(object) == T_STRING)                 return String::typeid;
    if (FIXNUM_P(object))                         return Int32::typeid;
    if (rb_obj_is_kind_of(object, rb_cNumeric))   return Single::typeid; // TODO: make this do single and double somehow ...

    VALUE klass        = rb_class_of(object);
    VALUE class_object = rb_iv_get(klass, "@clr_type");
    return (Type^)Marshal::ToObjectInternal(class_object);
  }

  array<Type^>^ RuntimeResolver::GetParameterTypes(int argc, VALUE *args) {
    array<Type^>^ sig = gcnew array<Type^>(argc);
    for (int i = 0; i < argc; ++i)
      sig[i] = MapRubyTypeToDotNetType(args[i]);
    return sig;
  }

  bool RuntimeResolver::IsExactMatch(array<Type^>^ rubyParameterTypes, array<Type^>^ methodParameterTypes) {
    if (rubyParameterTypes->Length != methodParameterTypes->Length) return false;
    for (int i = 0; i < rubyParameterTypes->Length; ++i) {
      if (rubyParameterTypes[i] == Single::typeid) {
        if (!(methodParameterTypes[i] == Single::typeid) && !(methodParameterTypes[i] == Double::typeid)) return false;
      }
      else
        if (rubyParameterTypes[i] != methodParameterTypes[i]) return false;
    }
    return true;
  }

  bool RuntimeResolver::IsMatchParameterArray(array<Type^>^ rubyParameterTypes, array<Type^>^ methodSignatureTypes) {
    Type^ parameterArrayType = methodSignatureTypes[methodSignatureTypes->Length - 1]->GetElementType();
    for (int i = 0; i < rubyParameterTypes->Length; ++i) {
      Type^ lhs = rubyParameterTypes[i];
      if (i < methodSignatureTypes->Length - 1) {
        Type^ rhs = methodSignatureTypes[i];
        if (!(lhs == rhs) && !lhs->IsSubclassOf(rhs)) return false;
      }
      else
        if (!(lhs == parameterArrayType) && !lhs->IsSubclassOf(parameterArrayType)) return false;
    }
    return true;
  }

  // TODO: will eventually have to deal with generics overloads as well
  int RuntimeResolver::FindBestMatch(array<Type^>^ rubyParameterTypes, array<array<Type^>^>^ methodSignatures, array<bool>^ isParameterArray) {
    int length = rubyParameterTypes->Length;
    for (int i = 0; i < methodSignatures->Length; ++i) {
      array<Type^>^ methodSignature = methodSignatures[i];
      //if (methodSignature->Length <= rubyParameterTypes->Length
      //    && isParameterArray[i] 
      //    && IsMatchParameterArray(rubyParameterTypes, methodSignature)) return i;

      if (length == methodSignature->Length) {
        bool found = true;
        for (int j = 0; j < length; ++j) { 
          Type^ lhs = rubyParameterTypes[j];
          Type^ rhs = methodSignature[j];
          if (lhs != rhs && !lhs->IsSubclassOf(rhs)) {
            found = false;
            break;
          }
        }
        if (found) return i;
      }
    }
    return -1;
  }

  int RuntimeResolver::FindExactMatch(array<Type^>^ rubyParameterTypes, array<array<Type^>^>^ methodSignatures) {
    for (int i = 0; i < methodSignatures->Length; ++i)
      if (IsExactMatch(rubyParameterTypes, methodSignatures[i])) return i;
    return -1;
  }

  int RuntimeResolver::GetMethodTableIndex(int methodId, int argc, VALUE *args) {
    MemberRef^ methodRef         = MetadataCache::Item[methodId];      
    array<Type^>^ parameterTypes = GetParameterTypes(argc, args);
    int result                   = FindExactMatch(parameterTypes, methodRef->MethodTable);
    return result == -1 ? FindBestMatch(parameterTypes, methodRef->MethodTable, nullptr) : result;
  }
}