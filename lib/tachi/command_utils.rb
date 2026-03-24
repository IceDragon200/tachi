module Tachi
  module CommandUtils
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
  end
end
