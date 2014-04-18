require 'wpf'

RubyClr::reference_file 'Valil.MathEquations.dll'

class Equation
  def initialize(string_expression)
    @expression = string_expression
  end
    
  def to_s
    @expression
  end
end

module Equation2
  SYMBOL_FONT_SIZE = 36

  @@symbols = {
    'square_root'      => 0x221a,
    'cube_root'        => 0x221b,
    'fourth_root'      => 0x221c,
    'proportional_to'  => 0x221d,
    'integral'         => 'super_sub(0x222b, *args)',
    'double_integral'  => 'super_sub(0x222c, *args)',
    'triple_integral'  => 'super_sub(0x222d, *args)',
    'contour_integral' => 'super_sub(0x222e, *args)',
    'surface_integral' => 'super_sub(0x222f, *args)',
    'volume_integral'  => 'super_sub(0x2230, *args)',
    'sigma'            => 'under_over("&#x2211;", *args)', 
  }

  @@entities = {
    '<=', '&#x2264;',
    '>=', '&#x2265;',
    '<',  '&lt;',
    '>',  '&gt;',
    '!=', '&#x2260;',
    '+=', '&#x00b1;',
    'SIGMA', '&#x03b8;',
    'INFINITY', '&#x221e;'
  }
  
  @@re = /(.*?)\^(([\w\d]+)|(\([^\)]+\)))/
  
  def format(expr, margin = 1, size = 16)
    @@entities.each_key { |entity| expr = expr.gsub(entity, @@entities[entity]) }
    "<eq:MathTextBlock FontFamily='Palatino Linotype' FontSize='#{size}' FontStyle='Italic' Margin='#{margin}'>#{expr}</eq:MathTextBlock>"
  end
  
  def superscript(body, superscript)
    return Equation.new(<<-EOF
      <eq:RowPanel xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        <eq:SubSupPanel>
          #{expr(body)}
          <eq:EmptyElement/>
          #{format(superscript, 0, 12)}
          <eq:EmptyElement/>
        </eq:SubSupPanel>
      </eq:RowPanel>
    EOF
    )
  end

  def parse(expr)
    return expr.to_s if expr.is_a?(Equation)
    result = ''
    m = expr.match @@re
    return format(expr) if m == nil
    while m != nil
      base, expr = m[1], m[2]
      result += superscript(base, expr).to_s
      break if m.post_match == nil
      expr = m.post_match
      m = expr.match(@@re)
      result += format(expr) if m == nil
    end
    result
  end
  
  def expr(*args)
    expressions = ''
    args.each { |arg| expressions += parse(arg) }
    return Equation.new(<<-EOF
      <eq:RowPanel Margin="5,0,5,0" xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        #{expressions}
      </eq:RowPanel>
    EOF
    )
  end

  def under_over(symbol, from, to, body, font_size = SYMBOL_FONT_SIZE)
    return Equation.new(<<-EOF
      <eq:UnderOverPanel xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        <eq:MathTextBlock FontFamily="Lucida Sans Unicode" FontSize="#{font_size}" Margin="1" IsSymbol="True">#{symbol}</eq:MathTextBlock>
        #{expr(from)}
        #{expr(to)}
        #{expr(body)}
      </eq:UnderOverPanel>
    EOF
    )
  end

  def empty(expr)
    expr == nil ? Equation.new('<eq:EmptyElement/>') : expr
  end
  
  def limit(from, to, body)
    expr = Equation.new(<<-EOF
      <eq:RowPanel>
        #{expr(from)}
        <eq:MathTextBlock FontFamily='Lucida Sans Unicode' FontSize="12" Margin="1" IsSymbol="True">&#x2192;</eq:MathTextBlock>
        #{expr(to)}
      </eq:RowPanel>
    EOF
    )
    return under_over('lim', expr, empty(nil), empty(body), 12)
  end
  
  def fraction(numerator, denominator)
    return Equation.new(<<-EOF
      <eq:RowPanel xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        <eq:FractionPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
          #{expr(numerator)}
          <Line Stroke="Black" StrokeThickness="2" StrokeEndLineCap="Round" StrokeStartLineCap="Round"/>
          #{expr(denominator)}
        </eq:FractionPanel>
      </eq:RowPanel>
    EOF
    )
  end
  
  def equals(lhs, *expressions)
    if expressions.length == 1
      rhs = expr(*expressions)
    else
      equations = ''
      expressions.each do |expression|
        equations += <<-EOF
          <eq:RowPanel HorizontalAlignment="Left" Margin="0,3">
            #{expr(expression)}
          </eq:RowPanel>
        EOF
      end
      rhs = <<-EOF
        <eq:HorizontalFencedPanel>
          <eq:MathTextBlock IsSymbol="True">{</eq:MathTextBlock>
          <eq:ColumnPanel>
            #{equations}
          </eq:ColumnPanel>
          <eq:EmptyElement/>
        </eq:HorizontalFencedPanel>
      EOF
    end
    return Equation.new(<<-EOF
      <eq:RowPanel xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        #{expr(lhs)}
        <eq:MathTextBlock Margin="1" FontStyle="Italic" xml:space="preserve" IsSymbol="True"> =  </eq:MathTextBlock>
        #{rhs}
      </eq:RowPanel>
    EOF
    )
  end
  
  def super_sub(symbol, sub_text, super_text, body_text)
    return Equation.new(<<-EOF
      <eq:RowPanel xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        <eq:SubSupPanel>
          <eq:MathTextBlock FontFamily="Lucida Sans Unicode" FontSize="#{SYMBOL_FONT_SIZE}" Margin="1" IsSymbol="True">&##{symbol.to_s};</eq:MathTextBlock>
          #{expr(sub_text)}
          #{expr(super_text)}
          #{expr(body_text)}
        </eq:SubSupPanel>
      </eq:RowPanel>
    EOF
    )
  end
  
  def radical(expr)
    return Equation.new(<<-EOF
      <eq:RowPanel xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        <eq:RadicalPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
          <eq:EmptyElement Margin="1"/>
          <Polyline Points="0,0 0,0 0,0 0,0 0,0" Stroke="Black" StrokeThickness="2" StrokeEndLineCap="Round" StrokeStartLineCap="Round" StrokeLineJoin="Round"/>
          <eq:RowPanel>
            #{expr(expr)}
          </eq:RowPanel>
        </eq:RadicalPanel>
      </eq:RowPanel>
    EOF
    )
  end

  def parens(*expr)
    return Equation.new(<<-EOF
      <eq:HorizontalFencedPanel xmlns:eq="clr-namespace:Valil.MathEquations;assembly=Valil.MathEquations">
        <eq:MathTextBlock IsSymbol="True">(</eq:MathTextBlock>
        #{expr(*expr)}
        <eq:MathTextBlock IsSymbol="True">)</eq:MathTextBlock>
      </eq:HorizontalFencedPanel>
    EOF
    )
  end

  def cols(*elements)
    equations = elements.collect { |element| expr(element) }
    return Equation.new(<<-EOF
      <eq:ColumnPanel>
        #{equations.join}
      </eq:ColumnPanel>
    EOF
    )
  end

  # TODO: make this a real method
  def matrix2
    return Equation.new(<<-EOF
      <eq:HorizontalFencedPanel>
        <eq:MathTextBlock IsSymbol="True">(</eq:MathTextBlock>
        <eq:MatrixPanel Columns="4" Rows="4">
          <eq:RowPanel>
            <eq:SubSupPanel>
              <eq:MathTextBlock FontStyle="Italic" Margin="1">tx</eq:MathTextBlock>
              <eq:EmptyElement/>
              <eq:MathTextBlock FontStyle="Italic" FontSize="12" Margin="1">2</eq:MathTextBlock>
              <eq:EmptyElement/>
            </eq:SubSupPanel>
            <eq:MathTextBlock Margin="1" FontStyle="Italic">+ c</eq:MathTextBlock>
          </eq:RowPanel>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">txy &#x2212; sz</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">txz + sy</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">0</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">txy + sz</eq:MathTextBlock>
          <eq:RowPanel>
            <eq:SubSupPanel>
              <eq:MathTextBlock FontStyle="Italic" Margin="1">ty</eq:MathTextBlock>
              <eq:EmptyElement/>
              <eq:MathTextBlock FontStyle="Italic" FontSize="12" Margin="1">2</eq:MathTextBlock>
              <eq:EmptyElement/>
            </eq:SubSupPanel>
            <eq:MathTextBlock Margin="1" FontStyle="Italic">+ c</eq:MathTextBlock>
          </eq:RowPanel>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">tyz &#x2212; sx</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">0</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">txz &#x2212; sy</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">tyz + sx</eq:MathTextBlock>
          <eq:RowPanel>
            <eq:SubSupPanel>
              <eq:MathTextBlock FontStyle="Italic" Margin="1">tz</eq:MathTextBlock>
              <eq:EmptyElement/>
              <eq:MathTextBlock FontStyle="Italic" FontSize="12" Margin="1">2</eq:MathTextBlock>
              <eq:EmptyElement/>
            </eq:SubSupPanel>
            <eq:MathTextBlock Margin="1" FontStyle="Italic">+ c</eq:MathTextBlock>
          </eq:RowPanel>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">0</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">0</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">0</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">0</eq:MathTextBlock>
          <eq:MathTextBlock Margin="1" FontStyle="Italic">1</eq:MathTextBlock>
        </eq:MatrixPanel>
        <eq:MathTextBlock IsSymbol="True">)</eq:MathTextBlock>
      </eq:HorizontalFencedPanel>
    EOF
    )
  end
    
  def method_missing(symbol, *args)
    if @@symbols.has_key?(symbol.to_s)
      eval(@@symbols[symbol.to_s])
    else
      raise "invalid symbol #{symbol}"
    end
  end
end

class Paragraph
  def initialize(string_expression = '')
    @expression = string_expression
  end
  
  def to_s
    "<Paragraph xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>#{@expression}</Paragraph>"
  end
  
  def text(*expressions)
    expressions.each { |expression| @expression += expression.to_s }
  end

  def line_break
    @expression += '<LineBreak />'
  end
    
  def self.add(element, &b)
    p = Paragraph.new.extend Equation2
    p.instance_eval(&b)
    reader  = XmlTextReader.new(StringReader.new(p.to_s))
    control = XamlReader.Load(reader)
    element.as(IAddChild).add_child(control)
    p
  end
end

class Section
  def self.add(element, title)
    xml = <<-EOF
      <Section xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
        <Paragraph>
          <Underline>#{title}</Underline>
        </Paragraph>
      </Section>
    EOF
    reader  = XmlTextReader.new(StringReader.new(xml.to_s))
    control = XamlReader.Load(reader)
    element.as(IAddChild).add_child(control)
    control
  end
end
