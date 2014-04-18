# This is a high-level helper library for Windows Forms programming. It can use
# any features of RubyCLR without restriction.

# Must include activerecord before rubyclr!
require 'rubygems'
require_gem 'activerecord'

require 'rubyclr'

RubyClr::reference 'System.Data'
RubyClr::reference 'System.Drawing'
RubyClr::reference 'System.Windows.Forms'

include System
include System::Data
include System::Data::SqlClient
include System::Drawing
include System::Windows::Forms
include System::Xml

module WinFormsApp
  include System::Windows::Forms

  def self.run(klass)
    Application.enable_visual_styles
    Application.set_compatible_text_rendering_default false
    Application.run(klass.new.form)
  end
end

class ShadowControl
  def layout(form)
    form.suspend_layout
    yield(form) if block_given?
    form
  ensure
    form.resume_layout(false)
    form.perform_layout
  end
end

class MainForm < ShadowControl
  attr_reader :form
end