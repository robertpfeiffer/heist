module Heist
  class Runtime
    
    class Scope
      attr_reader :runtime
      
      def initialize(parent = {})
        @symbols = {}
        is_runtime = (Runtime === parent)
        @parent = is_runtime ? {} : parent
        @runtime = is_runtime ? parent : parent.runtime
      end
      
      def [](name)
        name = to_name(name)
        bound = @symbols.has_key?(to_name(name))
        
        raise UndefinedVariable.new(
          "Variable '#{name}' is not defined") unless bound or Scope === @parent
            
        value = bound ? @symbols[name] : @parent[name]
        value = value.extract if Binding === value
        value
      end
      
      def []=(name, value)
        @symbols[to_name(name)] = value
        value.name = name if Function === value
        value
      end
      
      def defined?(name)
        @symbols.has_key?(to_name(name)) ||
            (Scope === @parent && @parent.defined?(name))
      end
      
      def set!(name, value)
        name = to_name(name)
        bound = @symbols.has_key?(name)
        
        raise UndefinedVariable.new(
          "Cannot set undefined variable '#{name}'") unless bound or Scope === @parent
        
        return @parent.set!(name, value) unless bound
        self[name] = value
      end
      
      def define(name, *args, &block)
        self[name] = Function.new(self, *args, &block)
      end
      
      def syntax(name, holes = [], &block)
        self[name] = Syntax.new(self, holes,&block)
      end
      
      # TODO: this isn't great, figure out a way for functions
      # to transparently handle inter-primitive calls so Ruby can
      # call Scheme code as well as other Ruby code
      def call(name, *params)
        self[name].body.call(*params)
      end
      
      def run(path)
        path   = path + FILE_EXT unless File.file?(path)
        source = Heist.parse(File.read(path))
        scope  = FileScope.new(self, path)
        source.eval(scope)
      end
      
      def eval(source)
        source = Heist.parse(source) if String === source
        source.eval(self)
      end
      
      def load(path)
        dir = load_path.find do |dir|
          File.file?("#{dir}/#{path}") or File.file?("#{dir}/#{path}#{FILE_EXT}")
        end
        return false unless dir
        runtime.run("#{dir}/#{path}")
        true
      end
      
      def current_file
        @path || @parent.current_file rescue nil
      end
      
      def current_continuation
        @runtime.stack.copy(false)
      end
      
    private
      
      def to_name(name)
        name.to_s.downcase
      end
      
      def load_path
        paths, file = [], current_file
        paths << File.dirname(file) if file
        paths + LOAD_PATH
      end
    end
    
    class FileScope < Scope
      extend Forwardable
      def_delegators(:@parent, :[]=, :eval, :run)
      
      def initialize(parent, path)
        super(parent)
        @path = path
        self['__FILE__'] = path
      end
    end
    
  end
end

