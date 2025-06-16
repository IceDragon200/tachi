require 'optparse'
require_relative 'config'

module Tachi
  class Application
    VERSION = "0.4.0".freeze

    def initialize
      @config_filename = File.join(Dir.home(), ".tachi/config")
      @context_name = nil
      @env = {}
    end

    def with_command_env(cmd)
      Dir.chdir cmd[:dirname] do
        env =
          {}
          .merge(@context.resolve_env(wd: cmd[:dirname]))
          .merge(get_environment_for_path(cmd[:dirname]))

        yield env, cmd
      end
    end

    def execute_command(cmd, command_args)
      with_command_env(cmd) do |env, _cmd|
        puts cmd[:command]
        result = system env, cmd[:path], *command_args
        result
      end
    end

    def describe_command(cmd)
      with_command_env(cmd) do |env, _cmd|
        puts "Command #{cmd[:command]}",
          "\tPATH: #{cmd[:path]}",
          "\tENV:",
          *(env.map do |(key, value)|
            "\t\t#{key}=#{value}"
          end)
      end
    end

    def describe_commands(commands)
      commands.each do |cmd|
        describe_command(cmd)
      end
    end

    def view_command(cmd)
      puts File.read(cmd[:path])
    end

    def view_commands(commands)
      commands.each do |cmd|
        view_command(cmd)
      end
    end

    def list_commands(commands)
      commands_list =
        commands.map do |row|
          "\t* " + row[:command]
        end.sort.join("\n")

      puts <<~__EOF__
      Available commands are:
      #{commands_list}
      __EOF__
    end

    def show_help
      puts "HELP"
      list_commands(@commands)
    end

    def scan_for_commands
      Dir.chdir @context.root_path do
        Dir.glob("**/cmd.*.sh")
      end.map do |filename|
        basename = File.basename(filename, File.extname(filename))

        _,command = *basename.split("cmd.")
        command = File.join(File.dirname(filename), command).gsub("/", ".")

        path = File.join(@context.root_path, filename)

        {
          command: command,
          basename: basename,
          dirname: File.dirname(path),
          path: path,
        }
      end
    end

    def match_command_segments?(given, expected)
      i = 0
      i2 = 0
      i3 = 0
      len = [given.size, expected.size].max

      ok = true
      while i3 < len
        a = given[i]
        b = expected[i2]

        if a == b
          i += 1
          i2 += 1
          i3 += 1
        elsif b == "*"
          while b == "*"
            i2 += 1
            b = expected[i2]
          end

          until a == b or i > given.size
            i += 1
            a = given[i]
          end

          if a != b
            ok = false
            break
          end
        else
          ok = false
          break
        end
      end

      ok
    end

    def find_commands(command)
      wanted_commands = split_command(command)
      @commands.filter do |row|
        wanted_commands.any? do |command_segments|
          command, = *split_command(row[:command])
          match_command_segments?(command, command_segments)
        end
      end
    end

    def get_environment_for_path(path, acc = {})
      @env_cache ||= {}

      if path == "/" or path == @context.root_path or path.empty?
        return acc
      end

      if File.directory?(path)
        env_path = File.join(path, "environment")
        if File.file?(env_path)
          result = {}
          File.read(env_path).split("\n").each do |line|
            key, value = line.split("=")
            key = key.strip
            value = value.strip
            unless key.empty?
              result[key] = value
            end
          end
          @env_cache[path] = result
        end
      end

      if @env_cache[path]
        acc.merge!(@env_cache[path])
      end

      get_environment_for_path(File.dirname(path), acc)
    end

    def load_config
      @config = Tachi::Config.load_file(@config_filename)
      @context_name ||= @config.default_context

      context = @config.get_context(@context_name)
      case context
      when Tachi::Config::Context
        @context = context
      else
        fail "context not found: #{@context_name}"
      end
    end

    def process_argv(argv)
      parser = OptionParser.new do |opts|
        opts.banner = "Tachi v#{VERSION} the useful sidearm"
        opts.on '-c', '--config-file FILENAME', String, "The configuration file that should be pulled. (default. #{@config_filename})" do |value|
          @config_filename = value
        end

        opts.on '', '--context NAME', String, "The context to use. (default. #{@context})" do |value|
          @context_name = value
        end
      end
      parser.parse(argv)
    end

    def main(argv)
      argv = process_argv(argv)

      load_config

      @commands = scan_for_commands
      case argv
        in []
          show_help
        in ["help"]
          show_help
        in ["describe"]
          show_help
          abort
        in ["view", segment]
          cmds = find_commands(segment)
          view_commands(cmds)
        in ["describe", segment]
          cmds = find_commands(segment)
          describe_commands(cmds)
        in ["find", segment]
          cmds = find_commands(segment)
          list_commands(cmds)
        in ["env"]
          puts YAML.dump(@context.resolve_env(wd: Dir.pwd))
        in ["run"]
          show_help
          abort
        in ["run", command, *command_args]
          cmds = find_commands(command)

          if cmds.empty?
            warn "Command pattern unmatched: #{command}"
            show_help
            abort
          else
            successful_commands = []
            failed_commands = []

            cmds.each do |cmd|
              result = execute_command(cmd, command_args)

              if result
                successful_commands << cmd
              else
                failed_commands << cmd
              end
            end

            total_commands = cmds.size
            puts "Completed #{successful_commands.size}/#{failed_commands.size}/#{total_commands}"
          end

        in ["version"]
          puts "Tachi v#{VERSION}"

        else
          show_help
          abort
      end
    end

    # @args command [String]
    # @returns Array<Array<String>>
    def split_command(command)
      result = []
      segments = command.split(".")
      segments.each do |segment|
        case segment
        when /\A\{(.+)\}\z/
          sub_segments = $1.split(",")
          if result.empty?
            sub_segments.each do |sub_segment|
              result.push([sub_segment])
            end
          else
            old_result = result
            result = []
            old_result.each do |base_segments|
              sub_segments.each do |sub_segment|
                new_base_segments = base_segments.dup()
                new_base_segments.push(sub_segment)
                result.push(new_base_segments)
              end
            end
          end
        when String
          if result.empty?
            result.push([segment])
          else
            result.each do |base_segments|
              base_segments.push(segment)
            end
          end
        else
          raise "unexpected command segment: #{segment.inspect}"
        end
      end
      result
    end
  end
end
