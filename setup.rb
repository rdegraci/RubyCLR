puts 'Generating setup script setup.cmd:'

File.open('setenv.cmd', 'w') do |f|
  f << "SET RUBYLIB=#{Dir.pwd}/Build;#{Dir.pwd}/Src/Ruby"
end
