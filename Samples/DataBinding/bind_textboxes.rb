# This sample demonstrates simple data binding using the new BindingSource
# class in Windows Forms 2.0. The BindingSource class is responsible for
# mapping properties on its data source to controls. It also handles
# automatic notification updates as well via the INotifyPropertyChanged
# interface that's implemented auto-magically on ActiveRecord objects that
# declare notify_when_property_changed in their class definition.

require 'winforms'

include ActiveRecord

Base.establish_connection(:adapter => 'sqlserver',
                          :host => '.\SQLEXPRESS',
                          :database => 'rubyclr_tests')

class Person < Base
  notify_when_property_changed
end

class MainForm
def create_textbox(form, top, left, binding_source, bound_property_name)
  textbox = TextBox.new
  textbox.top = top
  textbox.left = left
  textbox.data_bindings.add('Text', binding_source, bound_property_name)
  form.controls.add(textbox)
end
  
  def initialize
    form       = Form.new
    form.width = 600
    form.text  = 'ActiveRecord and Windows Forms'

    @john = Person.find_first
    binding_source = @john.as_binding_source

    create_textbox(form, 30, 10, binding_source, 'name')
    create_textbox(form, 60, 10, binding_source, 'age')    
    create_textbox(form, 60, 120, binding_source, 'age')

    change_button = Button.new
    change_button.text = 'Age Me!'
    change_button.click do |sender, args|
      # Notice that I'm changing the ActiveRecord object here!
      @john.age += 1
    end

    form.controls.add(change_button)
    
    @form = form
  end
end

WinFormsApp.run(MainForm)
