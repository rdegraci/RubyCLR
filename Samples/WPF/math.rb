require 'math_lib'

include System
include System::IO
include System::Xml

# TODO: this is an interesting bug - ActiveSupport defines Object#load
# but I need to call load as well dynamically - how do I workaround these
# without forcing the user to use the explicit .NET method name?

window   = XamlReader.Load(System::IO::File.open_read('math_app.xaml'))
button   = window.find_name('button')
input    = window.find_name('input')
equation = window.find_name('equation')
document = window.find_name('document')

fundamentals = Section.add(document, 'Fundamental Theorems of Calculus')

Paragraph.add(fundamentals) do
text 'The first fundamental theorem of calculus states that, if ', expr('f')
text 'is continuous on the closed interval', expr('[a,b]'), 'and', expr('F')
text 'is the is the antiderivative (indefinite integral) of ', expr('f')
text 'on', expr('[a,b]'), ', then '
text equals(integral('a', 'b', 'f(x) dx'), expr('F(b) - F(a)')), '.'
end

Paragraph.add(fundamentals) do
  text 'The second fundamental theorem of calculus holds for', expr('f')
  text 'continuous on an open interval', expr('I'), 'and', expr('a')
  text 'any point in', expr('I'), ', and states that if', expr('F')
  text 'is defined by', expr('F(x) = '), integral('a', 'x', 'f(t) dt')
  text 'then', expr('F\'(x) = f(x)'), 'at each point in', expr('I'), '.'
end

pinching = Section.add(document, 'Pinching Theorem')

Paragraph.add(pinching) do
  text 'Let', expr('g(x) <= f(x) <= h(x)'), 'for all', expr('x')
  text 'in some open interval containing', expr('a'), '. If'
  text equals(limit('x', 'a', 'g(x)'), limit('x', 'a', 'h(x) = L')), ', then'
  text limit('x', 'a', 'f(x) = L')
end

absolute_value = Section.add(document, 'Absolute Value')

Paragraph.add(absolute_value) do
  text 'The absolute value of a real number', expr('x'), 'is denoted', expr('|x|')
  text 'and defined as the "unsigned" portion of', expr('x'), ','
  text equals('|x|', '-x, x < 0', '0, x = 0', 'x, x > 0')
end

quadratic = Section.add(document, 'Quadratic Equation')

Paragraph.add(quadratic) do
  text 'A quadratic equation is a second-order polynomial equation in a single variable'
  text expr('x', 'ax^2 + bx + c = 0'), 'with', expr('a != 0')
  text '. Because it is a second-order polynomial equation, the fundamental '
  text 'theorem of algebra guarantees that it has two solutions. These '
  text 'solutions may be both real or both complex.'
end

Paragraph.add(quadratic) do
  text 'The roots can be found by completing the square,'
  line_break
  text equals(expr('x^2 + ', fraction('b', 'a'), 'x'),
              expr('-', fraction('c', 'a')))
  line_break
  text equals(superscript(parens('x + ', fraction('b', '2a')), '2'),
              expr('-', fraction('c', 'a'), ' + ', fraction('b^2', '4a^2')))
  line_break
  text equals(superscript(parens('x + ', fraction('b', '2a')), '2'),
              fraction('b^2 - 4ac', '4a^2'))
  line_break
  text equals(expr('x + ', fraction('b', '2a')),
              fraction(expr('+-', radical('b^2 - 4ac')), '2a'))
  line_break
  text 'Solving for', expr('x'), 'then gives'
  text equals('x', fraction(expr('-b += ', radical('b^2 - 4ac')), '2a'))
  text '. This equation is known as the quadratic forumla.'
end

binomial = Section.add(document, 'Binomial Theorem')

Paragraph.add(binomial) do
  text 'The binomial theorem states that for positive integers'
  text equals(expr('n, ', superscript(parens('x + a'), 'n')),
              expr(sigma('k = 0', 'n', parens(cols('n', 'k'))), 'x^k a^(n-k)'))
  text ', where', parens(cols('n', 'k')), ' are binomial coefficients.'
end

Paragraph.add(binomial) do
  text 'Newton showed that a similar forumla (with infinite upper limit) holds '
  text 'for negative integers', expr('-n')
  text equals(expr('n, ', superscript(parens('x + a'), '-n')),
              expr(sigma('k = 0', 'INFINITY', parens(cols('-n', 'k'))), 'x^k a^(-n - k)'))
  text 'the so-called negative binomial series, which converges for', expr('|x| < a')
  text '. In fact, the generalization'
  text equals(superscript(parens('1 + z'), 'a'),
              expr(sigma('k = 0', 'INFINITY', parens(cols('a', 'k'))), 'z^k'))
  text 'holds for all complex', expr('a'), 'and', expr('|z| < 1'), '.'
end

matrix = Section.add(document, 'Rotation Matrix')

Paragraph.add(matrix) do
  text equals('R', matrix2), line_break, 'where', expr(equals('c', 'cos SIGMA'),
                                                       equals('s', 'sin SIGMA'),
                                                       equals('t', '1 - cos SIGMA'))
  text 'and', expr('x, y, z'), 'is a unit vector on the axis of rotation.'
end

button.click do |sender, args|
  begin
    expression = <<-EOF
      Paragraph.add(document) do
        #{input.text}
      end
    EOF
    eval(expression)
  rescue
    puts $!
  end
end

Application.new.run(window)
