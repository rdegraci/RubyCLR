# This module contains all of the code for dynamic runtime compilation.
# Currently I support C#, VB.NET and JScript.NET as inline-able languages.

class Compiler
  def initialize(lang)
    @lang   = lang
    @params = System::CodeDom::Compiler::CompilerParameters.new
    @params.generate_in_memory = true    
    @references = []
    
    case lang
    when :csharp
      @compiler = Microsoft::CSharp::CSharpCodeProvider.new      
    when :vb
      @compiler = Microsoft::VisualBasic::VBCodeProvider.new
    when :jscript
      @compiler = Microsoft::JScript::JScriptCodeProvider.new
    when :xaml
      @compiler = nil      
    else
      raise ArgumentError, "Unknown language: #{lang}"
    end
  end

  def raise_external_compiler_exception(result)
    message = result.errors.collect do |error|
      "#{error.file_name}(#{error.line}, #{error.column}): #{error.error_number}: #{error.error_text}"
    end
    raise ArgumentError, message.join("\n")
  end

  def internal_compile(source)
    return compile_xaml(source) if @compiler == nil
    
    if @references.length > 0
      command_line_args = @references.collect { |ref| "/r:#{ref}" }.join(' ')
      @params.compiler_options = command_line_args
    end
    
    result = yield(source)

    if result.native_compiler_return_value == 0 
      types = get_types_in_assembly(result.compiled_assembly)
      RubyClr::generate_modules(types)
    else
      raise_external_compiler_exception(result)
    end
  end

  def compile(*source)
    internal_compile(source) do |source|
      @compiler.compile_assembly_from_source(@params, source.to_ary_of(System::String))
    end
  end
  
  def compile_file(*files)
    internal_compile(files) do |files|
      @compiler.compile_assembly_from_file(@params, files.to_ary_of(System::String))
    end
  end
  
  def reference(*assemblies)
    @references.concat(assemblies)
  end
end

class Module
  def inline(lang = :csharp)
    yield Compiler.new(lang)
  end
end
