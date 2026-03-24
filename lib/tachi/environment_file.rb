module Tachi
  #
  # EnvironmentFile handling:
  #
  # Usage:
  #
  #   EnvironmentFile.read_file("my_environment_file") #=> {"KEY" => "VALUE"}
  #
  module EnvironmentFile
    class InvalidEnvironmentVariableError < StandardError
    end

    # @param filename [String] the filename of the environment file to read
    def read_file(filename)
      result = {}
      File.read(filename).split("\n").each_with_index do |line, line_no|
        case line
        when /^\s*#/i
          # This is a comment line, we'll just skip over it

        when /^\s*$/
          # blank line

        else
          key, value = line.split("=", 2)

          if value.nil?
            raise InvalidEnvironmentVariableError, "value cannot be nil: #{filename}:#{line_no+1}"
          end

          key = key.strip
          value = value.strip
          unless key.empty?
            result[key] = value
          end
        end
      end
      result
    end

    extend self
  end
end
