# Sample by Justin Bailey

require 'rubyclr'

RubyClr::reference 'System'
RubyClr::reference 'System.Drawing'
RubyClr::reference 'System.Windows.Forms'

include System::Drawing
include System::Drawing::Drawing2D
include System::Windows::Forms

require 'open-uri'
require 'cgi'

class GoogleCalc
  def self.calc(expr)
    open(("http://www.google.com/search?q=#{CGI.escape(expr.strip)}")) do |f|
      if f.status.include? "200"
        begin
          matches = MATCH_EXP.match(f.read)
          return result_format(matches[2])
        rescue NoMethodError
         return "==> Expression not understood."
        rescue Exception
         return "==> Expression not understood. (#{$!.class.inspect},#{$!.inspect})"
        end
      else
        return "==> Response error: #{f.status.inspect}"
      end
    end
  end

private
  MATCH_EXP = Regexp.new("<b>(.*?) = (.*?)</b>")

  def self.result_format(s)
    s.gsub("<font size=-2></font>",",").gsub("&#215;","x").gsub("<sup>","^").gsub("</sup>", "")
  end
end

class MainForm
  attr_accessor :form

  def initialize
    form = Form.new
    form.FormBorderStyle =  FormBorderStyle::Sizable
    form.SizeGripStyle = SizeGripStyle::Show
    form.StartPosition = FormStartPosition::CenterScreen
    form.Text = "Ruby WinForms Google Calculator"
    form.Size = Size.new(220, 200)

    expressionGroupBox = GroupBox.new
    expressionGroupBox.Dock = DockStyle::Top
    expressionGroupBox.Width = 215
    expressionGroupBox.Height = 50
    expressionGroupBox.Text = "Expression"

    expressionTextBox = TextBox.new
    expressionTextBox.Location = Point.new(5, 20)
    expressionTextBox.Size = Size.new(125, 21)
    expressionTextBox.Anchor = AnchorStyles::Left | AnchorStyles::Top | AnchorStyles::Right
    expressionTextBox.tab_index = 0
    
    calcButton = Button.new
    calcButton.Size = Size.new(75, 23)
    calcButton.Location = Point.new(135, 19)
    calcButton.Text = "Calculate"
    calcButton.Anchor = AnchorStyles::Right | AnchorStyles::Top
    calcButton.Enabled = false
    calcButton.tab_index = 1
    
    expressionGroupBox.Controls.Add(expressionTextBox)
    expressionGroupBox.Controls.Add(calcButton)

    resultGroupBox = GroupBox.new
    resultGroupBox.Dock = DockStyle::Fill
    resultGroupBox.Text = "Results"
    resultGroupBox.Size = Size.new(100, 100)

    resultTextBox = TextBox.new
    resultTextBox.Location = Point.new(5, 20)
    resultTextBox.Size = Size.new(90, 75)
    resultTextBox.Anchor = AnchorStyles::Right | AnchorStyles::Top | AnchorStyles::Left | AnchorStyles::Bottom
    resultTextBox.Multiline = true
    resultTextBox.ReadOnly = true
    resultTextBox.tab_stop = false

    expressionTextBox.TextChanged do |sender, args|
      calcButton.Enabled = (expressionTextBox.Text.strip != "")
    end

    calcButton.Click do |sender, args|
      begin
        calcButton.Text = "Working ..."
        calcButton.Enabled = false
        resultTextBox.Text = GoogleCalc.calc(expressionTextBox.Text)
      rescue Exception
        resultTextBox.Text = "==> Error occurrred: $!.message"
      ensure
        calcButton.Text = "Calculate"
        calcButton.Enabled = true
      end
    end

    resultGroupBox.Controls.Add(resultTextBox)

    form.Controls.Add(resultGroupBox)
    form.Controls.Add(expressionGroupBox)
    form.accept_button = calcButton
    form.PerformLayout

    @form = form
  end
end

Application.enable_visual_styles
Application.set_compatible_text_rendering_default false
Application.run(MainForm.new.form) 