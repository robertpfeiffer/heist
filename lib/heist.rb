require 'rubygems'
require 'treetop'

module Heist
  VERSION = '0.1.0'
  
  NORMAL_ORDER      = LAZY  = 0
  APPLICATIVE_ORDER = EAGER = 1
  
  ORDERS = %w(normal applicative)
  
  ROOT_PATH    = File.expand_path(File.dirname(__FILE__))
  PARSER_PATH  = ROOT_PATH + '/parser/'
  RUNTIME_PATH = ROOT_PATH + '/runtime/'
  BUILTIN_PATH = ROOT_PATH + '/builtin/'
  LIB_PATH     = ROOT_PATH + '/stdlib/'
  
  require PARSER_PATH + 'scheme'
  require PARSER_PATH + 'nodes'
  require RUNTIME_PATH + 'runtime'
  require ROOT_PATH + '/repl'
  
  LOAD_PATH = [LIB_PATH]
  FILE_EXT  = ".scm"
  
  class HeistError            < StandardError; end
  class RuntimeError          < HeistError; end
  class UndefinedVariable     < RuntimeError; end
  class SyntaxError           < RuntimeError; end
  class MacroError            < SyntaxError; end
  class MacroTemplateMismatch < MacroError; end
  
  def self.parse(source)
    @parser ||= SchemeParser.new
    @parser.parse(source)
  end
  
  def self.evaluate(expression, scope)
    Runtime::Expression === expression ?
        expression.eval(scope) :
        expression
  end
  
end

