require 'optparse'
require_relative 'config'
require_relative 'job_runner'
require_relative 'command_utils'
require_relative 'environment_file'

module Tachi
  class Application
    VERSION = "0.5.0".freeze

    include Tachi::CommandUtils

    def initialize
      @config_filename = File.join(Dir.home(), ".tachi/config")
      @job_runner = Tachi::JobRunner.new
      @context_name = nil
      @env = {}
      ["EXEC_PATH"].each do |key|
        if ENV.key?(key)
          @env[key] = ENV[key].dup
        end
      end
    end

    def build_command_env(cmd, unsafe: false)
      env = {}.merge!(@env)
      unless unsafe
        env.merge!(get_environment_for_path(cmd[:dirname]))
      end
      env.merge!(@context.resolve_env(wd: cmd[:dirname]))
      env
    end

    def enqueue_command(cmd, command_args)
      env = build_command_env(cmd)
      # puts ">>> #{cmd[:command]}"
      @job_runner.enqueue(env, cmd, command_args)
    end

    def run_queued_commands
      @job_runner.run
    end

    def describe_command(cmd)
      env = build_command_env(cmd)
      puts "Command #{cmd[:command]}",
        "\tPATH: #{cmd[:path]}",
        "\tENV:",
        *(env.map do |(key, value)|
          "\t\t#{key}=#{value}"
        end)
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
        Dir.glob("**/cmd.*").filter do |filename|
          basename = File.basename(filename)
          if File.file?(filename)
            _,command = basename.split("cmd.")
            extname = File.extname(command)
            @context.allowed_extensions.include?(extname)
          else
            false
          end
        end
      end.map do |filename|
        basename = File.basename(filename)
        _,command = *basename.split("cmd.")
        command = File.basename(command, File.extname(command))
        dirname = File.dirname(filename)

        command =
          if dirname == "."
            command
          else
            File.join(dirname, command)
          end.gsub("/", ".")

        path = File.join(@context.root_path, filename)

        {
          command: command,
          basename: basename,
          dirname: File.dirname(path),
          path: path,
        }
      end.sort_by do |row|
        row[:command]
      end
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

      if path.empty?
        return acc
      end

      if File.directory?(path)
        env_path = File.join(path, "environment")
        if File.file?(env_path)
          @env_cache[path] = Tachi::EnvironmentFile.read_file(env_path)
        end
      end

      if @env_cache[path]
        acc = @env_cache[path].merge(acc)
      end

      parent = File.dirname(path)
      if parent == "/" or path == @context.root_path
        return acc
      end
      get_environment_for_path(parent, acc)
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

        opts.on '-g', '--group PATH', String, "Grouping path" do |path|
          @job_runner.setup_groups(split_command(path))
        end

        opts.on '-j', '--jobs COUNT', Integer, "How many threads should be used to execute jobs in parallel? (default: 1)" do |jobs|
          if jobs <= 0
            raise OptionParser::InvalidArgument, "--jobs must be a positive integer"
          end
          @job_runner.thread_limit = jobs
        end

        opts.on '', '--noop', "Toggle no-operation flag to skip running commands" do
          @job_runner.noop = true
        end

        opts.on '', '--max-buffer-size SIZE', Integer, "Controls the job runner's maximum buffer size for IO before being force-flushed (default: #{@job_runner.max_buffer_size})" do |size|
          if size <= 0
            raise OptionParser::InvalidArgument, "--max-buffer-size must be a positive integer"
          end

          @job_runner.max_buffer_size = size
        end

        opts.on '', '--buffer-size SIZE', Integer, "Controls the job runner's buffer size for IO (default: #{@job_runner.buffer_size})" do |size|
          if size <= 0
            raise OptionParser::InvalidArgument, "--buffer-size must be a positive integer"
          end

          @job_runner.buffer_size = size
        end

        opts.on '-v', '--version', "Show" do
          puts "Tachi #{VERSION}"
          exit
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
          puts Psych.dump(build_command_env({dirname: Dir.pwd}, unsafe: true))
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
            cmds.each do |cmd|
              enqueue_command(cmd, command_args)
            end

            total_commands = cmds.size
            result = run_queued_commands()

            successful_commands = []
            failed_commands = []

            result.each do |command_result|
              case command_result.exit_status
              when 0
                successful_commands << command_result
              else
                failed_commands << command_result
              end
            end

            puts "Completed #{successful_commands.size}/#{failed_commands.size}/#{total_commands}"
            unless failed_commands.empty?
              failed_commands.each do |command_result|
                puts "\tFAILED #{command_result.cmd[:command]} exit-status=#{command_result.exit_status}"
              end
              exit 1
            end
          end

        in ["version"]
          puts "Tachi v#{VERSION}"

        else
          show_help
          abort
      end
    end
  end
end
