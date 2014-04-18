require 'rubyclr'

RubyClr::reference 'PresentationCore'
RubyClr::reference 'PresentationFramework'
RubyClr::reference 'WindowsBase'

include System
include System::IO
include System::Windows
include System::Windows::Markup

class Compiler
  def compile_xaml(source)
    System::Windows::Markup::XamlReader.load(StringReader.new(source))
  end
end

module Wpf
  def self.load_window(xaml_file)
    System::Windows::Markup::XamlReader.load(System::IO::File.open_read(xaml_file))
  end
  
  def self.run(startup_uri)
    include System
    include System::Windows

    app             = Application.new
    app.startup_uri = Uri.new(startup_uri, UriKind::RelativeOrAbsolute)
    app.run    
  end
end
