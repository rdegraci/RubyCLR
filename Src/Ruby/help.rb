# This file adds help functionality to RubyCLR. This is an example of a
# plug-in, which will be dropped into a plug-in API later on. Code in this file
# can safely use any feature of RubyCLR.

include System

TYPE_COLOR      = ConsoleColor::White
EXCEPTION_COLOR = ConsoleColor::Yellow
PARAMETER_COLOR = ConsoleColor::Yellow
TEXT_COLOR      = ConsoleColor::Gray

ColorNode  = Struct.new(:color, :start, :length)

class ColorNode
  def <=>(other)
    self.start <=> other.start
  end
end

class ColorNodes
  def initialize
    @colors = []
  end

  def color_first_text(source, text, color)
    pos = source.index(text)
    @colors << ColorNode.new(color, pos, text.length) if pos
  end
  
  def color_all_text(source, text, color)
    pos = 0
    while pos = source.index(text, pos)
      @colors << ColorNode.new(color, pos, text.length)
      pos += text.length
    end
  end

  def colors
    @colors.sort
  end
end

module PrettyPrintHelpers
  include System
  
  def write(text, color = TEXT_COLOR)
    Console.foreground_color = color
    Console.write text
  end
  
  def print(text, color_nodes)
    nodes = color_nodes.colors
    pos   = 0
    nodes.each do |node|
      if node.start > pos
        write text[pos .. node.start - 1]
        pos = node.start
      end
      write text[node.start .. node.start + node.length - 1], node.color
      pos = node.start + node.length
    end
    write text[pos .. text.length] if pos < text.length
  end

  def crlf
    Console::write_line
  end
  
  def format
    f = Text::Format.new
    f.first_indent = 6
    f.body_indent  = 6
    yield f if block_given?
    Console::reset_color
  end
end

Info = Struct.new(:signature, :summary, :returns, :parameters, :exceptions, :member_info)

class Info
  include System::Reflection, PrettyPrintHelpers

  def print_list(f, list, item_color)
    if list.length > 0
      list.each do |p|
        text   = f.format("#{p.name}: #{p.description}\n")
        colors = ColorNodes.new
        colors.color_first_text(text, p.name, item_color)
        print text, colors
      end
    end
  end

  def print_signature(index = -1)
    method_name = member_info.name

    return_type = member_info.return_type.full_name if member_info.is_a?(MethodInfo)
    return_type = member_info.field_type.full_name  if member_info.is_a?(FieldInfo)
    return_type = member_info.property_type.full_name if member_info.is_a?(PropertyInfo)
    return_type = member_info.event_handler_type.get_method("Invoke").return_type.full_name if member_info.is_a?(EventInfo)

    params      = [] if member_info.is_a?(FieldInfo)
    params      = member_info.get_parameters if member_info.is_a?(MethodInfo)
    params      = member_info.get_get_method.get_parameters if member_info.is_a?(PropertyInfo)
    params      = member_info.event_handler_type.get_method("Invoke").get_parameters if member_info.is_a?(EventInfo)
    
    number      = index == -1 ? '' : "#{index + 1}." 
    colors      = ColorNodes.new
    parameters  = []

    if params.length > 0
      parameters = params.collect { |param| "#{param.parameter_type.full_name} #{param.name}" }
      text = "#{number} #{return_type} #{method_name}(#{parameters.join(', ')})\n\n"
    else
      text = "#{number} #{return_type} #{method_name}\n\n"
    end

    f              = Text::Format.new
    f.first_indent = index == -1 ? 6 : 3
    f.body_indent  = 8
    text           = f.format(text)

    colors.color_first_text(text, method_name, TYPE_COLOR)
    params.each do |param|
      colors.color_first_text(text, ' ' + param.name, PARAMETER_COLOR)
    end

    print text, colors
    crlf
  end
  
  def pretty_print(i = -1)
    format do |f|
      crlf
      print_signature(i)
      print_list(f, parameters, PARAMETER_COLOR)
      crlf if parameters.length > 0
      write f.format("#{summary}")
      crlf
      if returns.length > 0
        write f.format("Returns: #{returns}") 
        crlf
      end
      print_list(f, exceptions, EXCEPTION_COLOR)
      crlf
    end      
  end
end

TypeInfo = Struct.new(:name, :summary)

class TypeInfo
  include PrettyPrintHelpers
  
  def pretty_print
    format do |f|
      crlf
      write f.format(name), TYPE_COLOR
      crlf
      write f.format(summary)
      crlf
    end      
  end
end

InfoParameter = Struct.new(:name, :description)
InfoException = Struct.new(:name, :description)

module Help
  def self.is_element?(reader, name)
    reader.name == name and reader.node_type == XmlNodeType::Element
  end
  
  def self.is_end_element?(reader, name)
    reader.name == name and reader.node_type == XmlNodeType::EndElement
  end
  
  def self.element_name(element)
    element[2..element.length - 1]
  end
  
  def self.read_contents(reader, name)
    content = ''
    while reader.read
      break if is_end_element?(reader, name)
      content += "(see: #{element_name(reader.get_attribute('cref'))})" if is_element?(reader, 'see')
      content += reader.value if reader.node_type == XmlNodeType::Text
    end
    content
  end

  def self.get_parameter_types(parameters)
    parameters.collect { |param| param.parameter_type.full_name }
  end

  def self.read_xml_docfile(clr_type, search_strings)
    include System::Xml
    
    results = []
    path    = SYSTEM_PATH + clr_type.assembly.get_name.name + '.xml'
    auto_close(XmlTextReader.new(System::IO::File.open_read(path))) do |r|
      while r.read
        if is_element?(r, 'member')
          index = search_strings.index(r.get_attribute('name'))
          results << yield(r, index) if block_given? and index != nil
        end
      end
    end
    results
  end

  def self.get_member_help(clr_type, member_name)
    include System::Reflection
    
    methods = clr_type.get_members
    matches = []
    types   = {MethodInfo => 'M', EventInfo => 'E',
               FieldInfo => 'F', PropertyInfo => 'P'}
    
    0.upto(methods.length - 1) do |i|
      matches << methods[i] if types.has_key?(methods[i].class) and methods[i].name == member_name
    end
    
    if matches.length > 0
      prefix         = types[matches.first.class]
      search_strings = matches.collect do |member_info|
        params = [] if member_info.is_a?(FieldInfo)
        params = member_info.get_parameters if member_info.is_a?(MethodInfo)
        params = member_info.get_get_method.get_parameters if member_info.is_a?(PropertyInfo)
        # Events don't have parameter lists in XML doc help
        params = [] if member_info.is_a?(EventInfo)
        if params.length > 0
          "#{prefix}:#{member_info.declaring_type.full_name}.#{member_info.name}(#{get_parameter_types(params).join(',')})"
        else
          "#{prefix}:#{member_info.declaring_type.full_name}.#{member_info.name}"
        end
      end
      infos = read_xml_docfile(clr_type, search_strings) do |r, i|
        info = Info.new(r.get_attribute('name'), '', '', [], [], matches[i])
        while r.read
          break if is_end_element?(r, 'member') 
          info.summary = read_contents(r, 'summary') if is_element?(r, 'summary')
          info.returns = read_contents(r, 'returns') if is_element?(r, 'returns')
          info.parameters << InfoParameter.new(r.get_attribute('name'), read_contents(r, 'param')) if is_element?(r, 'param')
          info.exceptions << InfoException.new(element_name(r.get_attribute('cref')), read_contents(r, 'exception')) if is_element?(r, 'exception')
        end
        info
      end
      infos.first.pretty_print if infos.length == 1
      infos.each_with_index { |info, i| info.pretty_print(i) } if infos.length > 1
    end
    nil
  end
  
  def self.get_type_help(clr_type)
    search_string = ["T:#{clr_type.full_name}"]
    infos = read_xml_docfile(clr_type, search_string) do |r, i|
      info = TypeInfo.new(clr_type.full_name)
      while r.read
        break if is_end_element?(r, 'member')
        info.summary = read_contents(r, 'summary') if is_element?(r, 'summary')
      end
      info
    end
    infos.each { |info| info.pretty_print }
  end
end

class Object
  def auto_dispose(*objs)
    yield(*objs) if block_given?
  ensure
    objs.each do |obj|
      if obj != nil 
        disposable = obj.as IDisposable
        disposable.dispose if disposable != nil
      end
    end
  end
  
  def auto_close(*objs)
    yield(*objs) if block_given?
  ensure
    objs.each { |obj| obj.close if obj != nil }
  end
end