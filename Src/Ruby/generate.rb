# This file contains the implementation of the CIL shim generators for the
# RubyCLR bridge. The code in this file can only call methods in RbDynamicMethod
# and cannot contain any dependencies on higher-level RubyCLR functionality.

module RubyClrMacros
  def ld_this(klass)
    ld_self
    if klass.is_value_type? 
      ldc_i4_s   16
      add
      ldind_i4
    else
      call       'static Marshal::ToObjectInternal(VALUE)'
    end
  end

  def new_clrobj(ctor_info, sig = ctor_info.signatures.first)
    newobj   "#{ctor_info.clr_type}(#{sig.join(',')})"
  end

  def static_call(method_info, sig = method_info.signatures.first)
    call      "static #{method_info.clr_type}::#{method_info.member_name}(#{sig.join(',')})"
  end

  def inst_call(method_info, i = 0)
    method_name = "#{method_info.clr_type}::#{method_info.member_name}(#{method_info.signatures[i].join(',')})"

    callvirt  method_name  if method_info.is_virtual[i]
    call      method_name  unless method_info.is_virtual[i]
  end

  def ret_2rb(member_info, i = 0)
    marshal2rb    member_info.return_types[i], i
    ret
  end

  def match_sig(method_id)
    ldc_i4   method_id
    ld_argc
    ld_args
    call     'static RuntimeResolver::GetMethodTableIndex(Int32,Int32,UInt32*)'
  end

  def ld_rb_param(index, type)
    ld_args
    case index
    when 1:
      ldc_i4_4
      add
    when 2:
      ldc_i4_8
      add
    else
      ldc_i4    index << 2
      add
    end
    ldind_i4
    marshal2clr type
  end

  def ld_params(signature)
    signature.each_with_index do |param, j|
      ld_rb_param j, param
    end
  end
end

module Generate
  def self.marshal_ruby_object_to_clr(object)
    create_clr_shadow_class(object) do
      if method_info.member_type == 'method'  
        declare      'UInt32[]', :params
  
        ld_ruby_obj
        intern       Identifier::to_ruby_case(method_info.member_name)
        ldc_i4       method_info.signatures.first.length
        newarr      'UInt32'
        stloc       :params
        
        method_info.signatures.first.each_with_index do |type, i|
          ldloc       :params
          ldc_i4      i
          ldarg_s     i + 1
          marshal2rb  type
          stelem_i4
        end
        
        ldloc        :params
        call         'static RubyClr.Ruby::CallRubyMethod(VALUE,VALUE,UInt32[])'
        marshal2clr  method_info.return_types.first
        ret
      elsif method_info.member_type == 'property_get'
        ld_ruby_obj
        intern       method_info.member_name
        ldc_i4_0
        newarr       'UInt32'
        call         'static RubyClr.Ruby::CallRubyMethod(VALUE,VALUE,UInt32[])'
        marshal2clr  method_info.return_types.first
        ret
      elsif method_info.member_type == 'property_set'
        declare      'UInt32[]', :params
        
        ld_ruby_obj
        intern       method_info.member_name + '='
        ldc_i4_1
        newarr       'UInt32'
        stloc        :params
        
        ldloc        :params
        ldc_i4_0
        ldarg_1
        marshal2rb   method_info.signatures.first.first
        stelem_i4
        
        ldloc        :params
        call         'static RubyClr.Ruby::CallRubyMethod(VALUE,VALUE,UInt32[])'
        pop
        ret
      end
    end
  end
  
  def self.event_shim(klass, object, event_info, is_static, &block)
    create_event_shim(klass, object, event_info.member_name, is_static) do
      ld_block      block
      intern        'call'
      ldc_i4        event_info.signatures.first.length
      event_info.signatures.first.each_with_index do |type, i|
        ldarg_s     i
        marshal2rb  type
      end
      call_ruby_varargs  'rb_funcall', event_info.signatures.first.length
      marshal2clr        event_info.return_types.first
      ret
    end
  end

  def self.ctor_shim(klass, ctor_info)
    ctor_labels   = (1..ctor_info.signatures.length).collect { |i| ("l" + i.to_s).to_sym }
    is_value_type = klass.is_value_type? 

    create_safe_ruby_instance_method(klass, 'initialize') do
      declare     ctor_info.clr_type, :obj

      match_sig   ctor_info.member_id
      switch      ctor_labels
      throw_clr   'Cannot find method that matches Ruby parameters'

      if is_value_type
        ctor_info.signatures.each_with_index do |sig, i|
          label       ctor_labels[i]
          ldloca_s    :obj
          ld_params   sig
          call        ctor_info.clr_type + '(' + sig.join(',') + ')'
          br          :end_switch
        end
        
        label         :end_switch
        ret_valuetype :obj, ctor_info.clr_type
      else
        ctor_info.signatures.each_with_index do |sig, i|
          label       ctor_labels[i]
          ld_params   sig
          new_clrobj  ctor_info, sig
          stloc_s     :obj
          br          :end_switch
        end
        
        label         :end_switch
        ret_objref    :obj
      end
    end
  end

  def self.fastctor_shim(klass, ctor_info)
    is_value_type = klass.is_value_type? 
    
    create_safe_ruby_instance_method(klass, 'initialize') do
      declare     ctor_info.clr_type, :obj
      
      if is_value_type
        ldloca_s       :obj
        ld_params      ctor_info.signatures.first
        call           ctor_info.clr_type + '(' + ctor_info.signatures.first.join(',') + ')'
        ret_valuetype  :obj, ctor_info.clr_type
      else
        ld_params      ctor_info.signatures.first
        new_clrobj     ctor_info
        stloc_s        :obj
        ret_objref     :obj
      end
    end
  end

  def self.fastmethod_shim(klass, method_info)
    create_safe_ruby_instance_method(klass, method_info.ruby_member_name) do
      ld_this      klass
      ld_params    method_info.signatures.first
      inst_call    method_info
      ret_2rb      method_info
    end
  end
  
  def self.method_shim(klass, method_info)
    method_labels = (1..method_info.signatures.length).collect { |i| ("l" + i.to_s).to_sym }

    create_safe_ruby_instance_method(klass, method_info.ruby_member_name) do
      match_sig   method_info.member_id
      switch      method_labels
      throw_clr   'Cannot find method that matches Ruby parameters'

      method_info.signatures.each_with_index do |sig, i|
        label      method_labels[i]
        
        ld_this    klass
        ld_params  sig
        inst_call  method_info, i
        ret_2rb    method_info, i
      end
    end
  end
  
  def self.field_shim(klass, field_info)
    is_setter = field_info.ruby_member_name.rindex('=') == (field_info.ruby_member_name.length - 1)
    create_safe_ruby_instance_method(klass, field_info.ruby_member_name) do
      if is_setter
        ld_this      klass
        ld_rb_param  0, field_info.return_types[0]
        stfld        field_info.clr_type + '::' + field_info.member_name  
        ldc_i4_Qnil
        ret
      else
        ld_this      klass
        ldfld        field_info.clr_type + '::' + field_info.member_name  
        ret_2rb      field_info
      end
    end
  end

  def self.static_fastmethod_shim(klass, method_info)
    create_safe_ruby_singleton_method(klass, method_info.member_name) do
      ld_params    method_info.signatures.first 
      static_call  method_info
      ret_2rb      method_info
    end
  end
  
  def self.static_method_shim(klass, method_info)
    static_method_labels = (1..method_info.signatures.length).collect { |i| ("l" + i.to_s).to_sym }
    
    create_safe_ruby_singleton_method(klass, method_info.member_name) do
      match_sig   method_info.member_id
      switch      static_method_labels
      throw_clr   'Cannot find method that matches Ruby parameters'
      
      method_info.signatures.each_with_index do |sig, i|
        label        static_method_labels[i]
        
        ld_params    sig
        static_call  method_info, sig
        ret_2rb      method_info, i
      end
    end
  end
  
  def self.static_field_shim(klass, field_info)
    is_setter = field_info.ruby_member_name.rindex('=') == (field_info.ruby_member_name.length - 1)
    create_safe_ruby_singleton_method(klass, field_info.ruby_member_name) do
      if is_setter
        ld_rb_param  0, field_info.return_types[0]
        stsfld       'static ' + field_info.clr_type + '::' + field_info.member_name  
        ldc_i4_Qnil
        ret
      else
        ldsfld       'static ' + field_info.clr_type + '::' + field_info.member_name  
        ret_2rb      field_info
      end
    end
  end
end
