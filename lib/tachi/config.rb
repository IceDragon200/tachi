require 'psych'

module Tachi
  class ConfigError < RuntimeError
  end

  class Config
    class Context
      attr_accessor :name
      attr_accessor :root_path
      # Static environment variables
      attr_accessor :env
      # A set of environment variables that must be evaluated or calculated before use
      attr_accessor :calc_env
      attr_accessor :allowed_extensions

      def initialize
        @name = nil
        @root_path = nil
        @env = {}
        @calc_env = {}
        # All allowed file extensions that should be considered commands
        # "" is a special case which means commands without an extension are allowed
        @allowed_extensions = ["", ".sh", ".rb", ".py", ".pl"]
      end

      def resolve_env(wd:)
        result = {}
        result.merge!(@env)
        @calc_env.each do |(key, value)|
          result[key] = value.gsub(/\$\{(\w+)\}/) do |value|
            case $1
            when "ROOT_PATH"
              @root_path
            when "WD"
              wd
            else
              raise ConfigError, "could not resolve environment value: #{$1}"
            end
          end
        end
        result
      end

      def validate!
        unless @name
          fail "Context must have a name"
        end

        unless @root_path
          fail "Context must have a root path"
        end

        case @allowed_extensions
        when nil
          fail "Allowed extensions cannot be nil"
        when Array
          if @allowed_extensions.empty?
            fail "must have at least 1 allowed extension"
          end
        else
          fail "allowed_extensions must be an array"
        end
      end
    end

    attr_reader :contexts
    attr_reader :default_context

    def self.load_file(filename)
      case filename
      when String
        if File.exist?(filename)
          doc = Psych.load_file(filename)

          new(doc)
        else
          raise ConfigError, "config does not exist: #{filename}"
        end
      else
        raise ConfigError, "invalid config filename: #{filename.inspect}"
      end
    end

    def initialize(doc)
      @contexts = []
      @default_context = "default"

      case doc
      when Hash
        doc.each do |(key, value)|
          case key
          when "default_context"
            @default_context = value
          when "contexts"
            set_contexts(value)
          else
            raise ConfigError, "unexpected root key #{key}"
          end
        end
      else
        raise ConfigError, "expected hash"
      end

      validate!
    end

    def get_context(name)
      @contexts.find do |context|
        context.name == name
      end
    end

    def validate!
      if @contexts.empty?
        raise ConfigError, "no contexts"
      end
    end

    def set_contexts(doc)
      case doc
      when Array
        doc.each do |item|
          add_context(item)
        end
      else
        raise ConfigError, "expected contexts to be an array"
      end
    end

    def add_context(item)
      context = Context.new
      case item
      when Hash
        item.each do |(key, value)|
          case key
          when "root_path"
            context.root_path = value
          when "name"
            context.name = value
          when "env"
            context.env = value
          when "calc_env"
            context.calc_env = value
          when "allowed_extensions"
            context.allowed_extensions = value
          else
            raise ConfigError, "unexpected key in context object: #{key}"
          end
        end
      else
        raise ConfigError, "invalid context, expected a hash"
      end
      context.validate!
      @contexts.push(context)
    end
  end
end
