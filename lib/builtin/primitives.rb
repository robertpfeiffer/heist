# Functions that create new functions

# (define) binds values to names in the current scope.
# If the first parameter is a list it creates a function,
# otherwise it eval's the second parameter and binds it
# to the name given by the first.
syntax('define') do |scope, names, *body|
  List === names ?
      scope.define(names.first, names.rest, body) :
      scope[names] = Heist.evaluate(body.first, scope)
end

# (lambda) returns an anonymous function whose arguments
# are named by the first parameter and whose body is given
# by the remaining parameters.
syntax('lambda') do |scope, names, *body|
  Function.new(scope, names, body)
end

# (set!) reassigns the value of an existing bound variable,
# in the innermost scope responsible for binding it.
syntax('set!') do |scope, name, value|
  scope.set!(name, Heist.evaluate(value, scope))
end

#----------------------------------------------------------------

# Macros

syntax('define-syntax') do |scope, name, transformer|
  scope[name] = Heist.evaluate(transformer, scope)
end

syntax('let-syntax') do |*args|
  call('let', *args)
end

syntax('letrec-syntax') do |*args|
  call('letrec', *args)
end

syntax('syntax-rules') do |scope, keywords, *rules|
  Macro.new(scope, keywords, rules)
end

#----------------------------------------------------------------

# Continuations

syntax('call-with-current-continuation') do |scope, callback|
  continuation = Continuation.new(scope.runtime.stack)
  callback = Heist.evaluate(callback, scope)
  callback.call(scope, [continuation])
end

#----------------------------------------------------------------

# Quoting functions

# (quote) casts identifiers to symbols. If given a list, it
# quotes all items in the list recursively.
syntax('quote') do |scope, arg|
  case arg
  when List then
    arg.inject(List.new) do |list, cell|
      list << call('quote', scope, cell)
      list
    end
  when Identifier then arg.to_s.to_sym
  else arg
  end
end

# (quasiquote) is similar to (quote), except that when it
# encounters an (unquote) or (unquote-splicing) expression
# it will evaluate it and insert the result into the
# surrounding quoted list.
syntax('quasiquote') do |scope, arg|
  case arg
  when List then
    result = List.new
    arg.each do |cell|
      if List === cell
        case cell.first.to_s
        when 'unquote' then
          result << Heist.evaluate(cell.last, scope)
        when 'unquote-splicing' then
          list = Heist.evaluate(cell.last, scope)
          list.each { |value| result << value }
        else
          result << call('quasiquote', scope, cell)
        end
      else
        result << call('quasiquote', scope, cell)
      end
    end
    result
  when Identifier then arg.to_s.to_sym
  else arg
  end
end

#----------------------------------------------------------------

# Control structures

# (begin) simply executes a series of lists in the current scope.
syntax('begin') do |scope, *body|
  Body.new(body, scope)
end

# (if) evaluates the consequent if the condition eval's to
# true, otherwise it evaluates the alternative
syntax('if') do |scope, cond, cons, alt|
  which = Heist.evaluate(cond, scope) ? cons : alt
  Frame.new(which, scope)
end

#----------------------------------------------------------------

# Runtime utilities

define('exit') { exit }

syntax('runtime') do |scope|
  scope.runtime.elapsed_time
end

syntax('eval') do |scope, string|
  scope.eval(Heist.evaluate(string, scope))
end

define('display') do |expression|
  puts expression
end

syntax('load') do |scope, file|
  scope.load(file)
end

#----------------------------------------------------------------

# Arithmetic and other math functions

define('+') do |*args|
  args.any? { |arg| String === arg } ?
      args.inject("") { |str, arg| str + arg.to_s } :
      args.inject(0)  { |sum, arg| sum + arg }
end

define('-') do |op1, op2|
  op2.nil? ? 0 - op1 : op1 - op2
end

define('*') do |*args|
  args.inject(1) { |prod, arg| prod * arg }
end

define('/') do |op1, op2|
  op2.nil? ? 1.0 / op1 : op1 / op2.to_f
end

define('expt') do |op1, op2|
  op1 ** op2
end

define('remainder') do |op1, op2|
  op1 % op2
end

define('random') do |max|
  rand(max)
end

define('max') do |*args|
  args.max
end

define('min') do |*args|
  args.min
end

#----------------------------------------------------------------

# Comparators

define('eqv?') do |op1, op2|
  op1.class == op2.class && op1 == op2
end

define('=') do |op1, op2|
  # TODO raise an exception if they're not numeric
  Numeric === op1 && Numeric === op2 && op1 == op2
end

define('>') do |op1, op2|
  op1 > op2
end

define('<') do |op1, op2|
  op1 < op2
end

#----------------------------------------------------------------

# Type-checking predicates

define('complex?') do |value|
  call('real?', value) # || TODO
end

define('real?') do |value|
  call('rational?', value) || Float === value
end

define('rational?') do |value|
  call('integer?', value) || Float === value # TODO handle this properly
end

define('integer?') do |value|
  Integer === value
end

#----------------------------------------------------------------

# List-processing functions

define('cons') do |car, cdr|
  List.new([car] + cdr)
end

define('car') do |list|
  list.first
end

define('cdr') do |list|
  List.new(list).rest
end

define('append') do |list1, list1|
  List.new(list1+list2)
end

define('null?') do |list|
  list.empty?
end
