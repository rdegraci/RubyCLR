reference 'System.Windows.Forms'

include System::Collections
include System::ComponentModel
include System::Windows::Forms

module RubyClr
  module Bindable
    def get_binding_context
      raise NotImplementedError("#{self.class.name}#get_binding_context is not implemented.")
    end
  end
end

class ActiveRecord::Base
  # TODO: the Bindable idiom is confusing - need to wrap this up into something
  # that is a lot more simple than the next 4 lines of code!
  include RubyClr::Bindable
  
  def get_binding_context
    @attributes.keys
  end

  def as_binding_source
    binding_source = System::Windows::Forms::BindingSource.new
    binding_source.data_source = self
    binding_source
  end

  implements IDataErrorInfo
  
  def get__error
    errors.empty? ? nil : errors.full_messages.join(',')
  end
  
  def get__item(index)
    errors[index]
  end

  implements IEditableObject
  
  def begin_edit
    @is_editing = false if !defined?('@is_editing')
    if !@is_editing
      @backup_attributes = @attributes.dup
      @is_editing = true
    end
  end

  def cancel_edit
    if @is_editing
      @attributes = @backup_attributes
      @is_editing = false
    end
  end

  def end_edit
    @is_editing = false
  end
  
  def self.notify_when_property_changed
    self.class_eval <<-EOF
      implements INotifyPropertyChanged
    
      alias activerecord_method_missing method_missing
    
      def method_missing(symbol, *params)
        symbol_name   = symbol.to_s
        equals_offset = symbol_name =~ /=$/
    
        return activerecord_method_missing(symbol, *params) unless equals_offset
        
        attribute_name = symbol_name[0..equals_offset - 1]
        
        if !self.attributes.include?(attribute_name) or params.length != 1
          return activerecord_method_missing(symbol, *params)
        end
        
        write_attribute(attribute_name, params.first)
        if defined?(@clr_shadow_object)
          if @clr_shadow_object.property_changed != nil
            @clr_shadow_object.property_changed.invoke(@clr_shadow_object,
                                                       PropertyChangedEventArgs.new(attribute_name))
          end
        end
      end
    EOF
  end
end

class Struct
  include RubyClr::Bindable

  def get_binding_context
    self.members
  end
end

# This is a required patch for ActiveRecord which forces it to revert back
# to DateTime if a date is prior to 1970 ... or should this always be the case?
# TODO: double-check this as I got this from the rails wiki
#class ActiveRecord::ConnectionAdapters::Column
#  def self.string_to_time(string)
#    return string unless string.is_a?(String)
#    time_array = ParseDate.parsedate(string)[0..5]
#    begin
#      Time.send(Base.default_timezone, *time_array)
#    rescue
#      DateTime.new(*time_array) rescue nil
#    end
#  end
#end

class RubyEnumerator
  implements IEnumerator
  
  def initialize(ruby_object)
    @position = -1
    @ruby_object = ruby_object
  end

  # NOTE: crufty hack for properties right now will be "current" when done
  def get__current
    @ruby_object[@position]
  end

  def move_next
    @position += 1
    @ruby_object.length != @position
  end

  def reset
    @position = -1
  end
end

class Array
  implements IBindingList, ICancelAddNew, IDeletedRows
  
  # IDeletedRows methods
  def deleted_rows
    @deleted_rows
  end
  
  # ICancelAddNew methods
  def cancel_new(index)
    delete_at(index) if index == @new_object_index
  end
  
  def end_new(index)
    fire_list_changed(ListChangedType::ItemChanged, index)
  end

  def fire_list_changed(change_type, offset)
    if clr_shadow_object.list_changed != nil
      args = ListChangedEventArgs.new(change_type, offset)
      clr_shadow_object.list_changed.invoke(self, args)
    end
  end
  
  def as_binding_source
    self.each do |element|
      element.clr_shadow_object.property_changed do |sender, args|
        offset = self.index_of(sender)
        fire_list_changed(ListChangedType::ItemChanged, offset)
      end
    end
    self
  end

  # IBindingList properties
  def add_index
  end
  
  def add_new
    new_object = self.first.class.new
    @new_object_index = self.length
    self << new_object
    new_object
  end
  
  def get__allow_edit
    true
  end
  
  def get__allow_new
    true
  end
  
  def get__allow_remove
    true
  end
  
  def apply_sort
  end
  
  # TODO: find method name collision resolution
  
  def is_sorted
    false
  end
  
  def remove_index
  end
  
  def remove_sort
  end
  
  def get__sort_direction
  end

  def get__sort_property
  end
  
  def get__supports_change_notification
    true
  end
  
  def get__supports_searching
    false
  end
  
  def get__supports_sorting
    false
  end
  
  # IEnumerator properties  
  def get_enumerator
    RubyEnumerator.new(self)
  end

  # ICollection properties
  def get__count
    length
  end

  def get__is_synchronized
    false
  end
  
  # TODO: I believe returning nil is correct for non-thread-safe collections
  def get__sync_root
    puts 'calling sync_root'
    nil
  end

  # ICollection methods
  def copy_to
    puts 'calling copy_to'
  end
  
  # IList properties
  def get__is_fixed_size
    false
  end
  
  def get__is_read_only
    false
  end
  
  def get__item(index)
    return self[index]
  end

  def set__item(index, value)
    self[index] = value
  end
  
  # IList methods
  def add(item)
    self << item
    self.length
  end
 
  def contains(item)
    index_of(item) != -1
  end

  # Find the index of a clr shadow object in our collection
  def is_ruby_value_type(object)
    [String, Fixnum, Bignum, Time, Number, Float].include?(object.class)
  end
  
  def index_of(item)
    if is_ruby_value_type(item)
      result = index(item)
      return result == nil ? -1 : result
    else
      self.each_with_index do |element, index|
        return index if item.equals(element.clr_shadow_object)
      end
      -1
    end
  end
  
  def remove(item)
    remove_at(index_of(item))
  end
  
  def remove_at(index)
    @deleted_rows ||= []
    @deleted_rows << self[index]
    
    self.delete_at(index)
    fire_list_changed(ListChangedType::ItemDeleted, index)
  end
end
