require 'winforms'

include System
include System::Collections

Person = Struct.new(:name, :age)

class MainForm
  def initialize
    form      = Form.new
    form.Text = 'Bind an Array of Custom Structs'

    names = []
    names << Person.new('John', 38)
    names << Person.new('Carolyn', 37)
    names << Person.new('Matthew', 2)
    names << Person.new('Ben', 0)

    grid             = DataGridView.new
    grid.dock        = DockStyle::Fill
    grid.data_source = names
    
    form.controls.add(grid)
    
    @form = form
  end
end

WinFormsApp.run(MainForm)
