# Beauty new sample for Drop 4 of RubyCLR

require 'winforms'

include ActiveRecord
include System::ComponentModel

Base.establish_connection(:adapter  => 'sqlserver',
                          :host     => '.\SQLEXPRESS',
                          :database => 'rubyclr_tests')

class Person < Base
  notify_when_property_changed
end
#class Contact < Base
#  set_table_name 'Person.Contact'
#  set_primary_key 'ContactID'
#  
#  notify_when_property_changed
#  editable_object
#end
#
$code = <<-EOF
@people = Person.find_all
EOF

class MainForm
  def initialize
    form        = Form.new
    form.width  = 600
    form.height = 600
    form.text   = 'Interactive ActiveRecord'

    grid             = DataGridView.new
    grid.top         = 50
    grid.dock        = DockStyle::Fill

    form.controls.add(grid)

    panel        = Panel.new
    panel.height = 200
    panel.dock   = DockStyle::Top

    textbox        = TextBox.new
    textbox.top    = 10
    textbox.left   = 100
    textbox.width  = 20
    textbox.height = 180
    textbox.anchor = AnchorStyles::Right | AnchorStyles::Left
    textbox.multiline = true
    
    textbox.text = $code.gsub("\n", "\r\n")
    
    panel.controls.add(textbox)
    
    button      = Button.new
    button.text = '&Save'
    button.click do |sender, args|
      @people.each { |person| person.save }
      @people.deleted_rows.each { |row| row.class.delete(row.id) } if @people.deleted_rows != nil
      MessageBox.show('Saved')
    end
    
    panel.controls.add(button)

    change_button      = Button.new
    change_button.top  = 25
    change_button.text = '&Eval'
    change_button.click do |sender, args|
      instance_eval(textbox.text)
      grid.data_source = @people
    end

    panel.controls.add(change_button)
    
    form.controls.add(panel)
    
    @form = form
  end
end

WinFormsApp.run(MainForm)
