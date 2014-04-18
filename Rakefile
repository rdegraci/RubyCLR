# Simple build script for RubyCLR

# Global configuration settings - you may need to edit these based on where
# you installed the .NET FX and Ruby, and what version of the Ruby source code
# you are compiling from.

DOTNET_SYS_DIR       = 'c:\windows\microsoft.net\framework\v2.0.50727'
RUBY_SYS_DIR         = 'c:\ruby'
RUBY_SRC_DIR         = 'c:\ruby\ruby-1.8.2'

def ext(filename, new_extension)
  filename.sub(/\.[^.]+$/, new_extension)
end

OUTPUT_FILENAME      = 'Runtime.dll'
OUTPUT_PATH          = "Build\\#{OUTPUT_FILENAME}"
TEMP_OBJ_DIR         = 'Build\Temp\Debug\\'
DEBUG_DEFINES        = ['WIN32', '_DEBUG', '_WINDLL', '_UNICODE', 'UNICODE']
INCLUDE_DIRS         = ["#{RUBY_SRC_DIR}", "#{RUBY_SRC_DIR}\\win32"]
LIB_DIRS             = ["#{RUBY_SYS_DIR}\\lib"]
CL_DEBUG_SWITCHES    = "/clr /Od /I /FD /EHa /MDd /W3 /c /Zi /TP /Fo""#{TEMP_OBJ_DIR}\\\\"" /FU ""#{DOTNET_SYS_DIR}\\System.dll"" /FU ""#{DOTNET_SYS_DIR}\\System.Data.dll"""
SRC_FILES            = Dir['Src/Runtime/*.cpp']
TEST_SRC_FILES       = Dir['Src/TestTargets/*.cs'] + Dir['Src/TestTargets/Properties/*.cs']
OBJ_FILES            = SRC_FILES.collect { |f| ext(f, '.obj') }
LINK_DEBUG_SWITCHES  = '/DLL /MANIFEST /DEBUG /ASSEMBLYDEBUG /MACHINE:X86 /FIXED:No msvcrt-ruby18.lib'

def line_count(files, title)
  puts
  puts title
  puts '-' * 46
  group_lc = 0
  size     = 0
  files.each do |file|
    lc = 0
    size += File.size(file)
    File.open(file) do |f|
      while line = f.gets
        lc += 1 unless line.strip.empty?
      end
    end
    puts file.ljust(40) + lc.to_s.rjust(6)
    group_lc += lc
  end
  puts 'Total lines'.ljust(40) + group_lc.to_s.rjust(6)
  puts 'Total bytes'.ljust(40) + size.to_s.rjust(6)
  puts 'Bytes per line'.ljust(40) + (size / group_lc).to_s.rjust(6)
  group_lc
end

task :stats do
  lc = 0
  lc += line_count(Dir['Tests/*.rb'] + Dir['Src/TestTargets/*.cs'], 'Unit Tests')
  lc += line_count(Dir['Src/Ruby/*.rb'], 'Ruby Code')
  lc += line_count(Dir['Src/Runtime/*.h'] + Dir['Src/Runtime/*.cpp'], 'C++ Code')
  lc += line_count(Dir['Samples/*/*.rb'], 'Samples')
  puts
  puts "=" * 46
  puts "Grand Total".ljust(40) + lc.to_s.rjust(6)
end

task :compile do
  include_dirs = INCLUDE_DIRS.collect { |d| "/I #{d}" }
  defines      = DEBUG_DEFINES.collect { |d| "/D \"#{d}\"" }
  options      = "#{CL_DEBUG_SWITCHES} #{defines.join(' ')} #{include_dirs.join(' ')} #{SRC_FILES.join(' ')}"
  sh "cl #{options}"
end

task :link do
  obj_files = OBJ_FILES.collect { |f| "#{TEMP_OBJ_DIR}\\#{f.split('/').last}" }
  output    = "/OUT:#{OUTPUT_PATH}"
  lib_path  = "/LIBPATH:\"#{LIB_DIRS.join(';')}\""
  manifest  = "/MANIFESTFILE:\"#{TEMP_OBJ_DIR}\\#{OUTPUT_FILENAME}.intermediate.manifest\""
  options   = "#{output} #{lib_path} #{manifest} #{LINK_DEBUG_SWITCHES} ole32.lib #{obj_files.join(' ')}"
  sh "link #{options}"
end

task :mt do
  output_resource = "/outputresource:\"#{OUTPUT_PATH};#2\""
  manifest        = "/manifest #{TEMP_OBJ_DIR}\\#{OUTPUT_FILENAME}.intermediate.manifest"
  sh "mt #{output_resource} #{manifest}"
end

task :compile_test_targets do
  sh "csc /t:library /out:Tests\\TestTargets.dll #{TEST_SRC_FILES.join(' ').gsub('/', '\\')}"  
end

task :clean do
  extensions  = ['ncb', 'obj', 'exp', 'dll', 'ilk', 'pdb', 'exe', 'pch', 'manifest', 'htm', 'idb', 'lib', 'dep', 'vsp', 'rb~']
  dirs        = ['Build', 'Tests', '.']
  expressions = dirs.collect { |dir| extensions.collect { |ext| "#{dir}/*.#{ext}" } }.flatten

  rm_f FileList.new(expressions)
  dirs.each { |d| rm_f Dir["#{d}/*~"] }
end

task :tests do
  ruby "-w -CTests tests.rb"
end

task :prepare do
  begin
    sh "md #{TEMP_OBJ_DIR}"
  rescue
  end
end

task :default => [:prepare, :compile, :link, :mt, :compile_test_targets, :tests] do
end