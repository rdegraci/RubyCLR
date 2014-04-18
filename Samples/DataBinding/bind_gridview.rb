require 'winforms'

include ActiveRecord
include System::ComponentModel

Base.establish_connection(:adapter  => 'sqlserver',
                          :host     => '.\SQLEXPRESS',
                          :database => 'rubyclr_tests')

class Person < Base
  notify_when_property_changed
  
  def validate
    if age < 0 or age > 200
      errors.add('Age', 'must be between 0 and 200')
    end
  end
end

class MainForm
  def initialize
    form       = Form.new
    form.width = 600
    form.text  = 'ActiveRecord and Windows Forms'

    @people = Person.find_all    
    
    grid             = DataGridView.new
    grid.top         = 50
    grid.dock        = DockStyle::Fill
    grid.data_source = @people.as_binding_source

    grid.cell_leave do |sender, args|
      @people[args.row_index].validate
    end
    
    form.controls.add(grid)

    panel        = Panel.new
    panel.height = 50
    panel.dock   = DockStyle::Top
    
    button      = Button.new
    button.text = 'Save'
    button.click do |sender, args|
      @people.each { |person| person.save }
      @people.deleted_rows.each { |row| row.class.delete(row.id) } if @people.deleted_rows != nil
      puts 'saved'
    end
    
    panel.controls.add(button)

    change_button      = Button.new
    change_button.left = 100
    change_button.text = 'Age Us!'
    change_button.click do |sender, args|
      @people.each { |person| person.age += 1 }
    end

    panel.controls.add(change_button)
    
    form.controls.add(panel)
    
    @form = form
  end
end

WinFormsApp.run(MainForm)
