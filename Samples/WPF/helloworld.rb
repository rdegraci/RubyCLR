require 'wpf'

window = XamlReader.Load(System::IO::File.open_read('helloworld_app.xaml'))
button = window.find_name('button1')
button.click do |sender, args|
  puts 'clicked me!'
end
Application.new.run(window)
