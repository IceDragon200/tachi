require 'thread'

module Tachi
  class CommandResult
    attr_accessor :exit_status
    attr_accessor :cmd
    attr_accessor :env
    attr_accessor :args

    def initialize(exit_status:, cmd:, env:, args:)
      @exit_status = exit_status
      @cmd = cmd
      @env = env
      @args = args
    end
  end

  class UI
    def initialize(thread_limit:, max_buffer_size:)
      @thread_limit = thread_limit
      @max_buffer_size = max_buffer_size
      @contexts = {}
      @buffer = {}
    end

    def set_context(id, heading)
      @contexts[id] = heading
    end

    def puts(id, topic, blob)
      if @thread_limit > 1
        print "[#{topic}:#{id}] #{blob}#{$/}"
      else
        # print "#{topic}: #{blob}#{$/}"
        print "#{blob}#{$/}"
      end
    end

    def write(id, topic, blob)
      @buffer[id] ||= {}
      @buffer[id][topic] ||= ""
      @buffer[id][topic] += blob

      rest = @buffer[id][topic]
      loop do
        head, rest = rest.split($/, 2)
        break unless head # means rest is also nil

        if rest
          self.puts(id, topic, head)
        else
          rest = head
          head = nil
          break
        end
      end

      if rest && rest.size >= @max_buffer_size
        self.puts(id, topic, rest)
        rest = nil
      end

      if rest.nil? || rest.empty?
        @buffer[id].delete(topic)
        if @buffer[id].empty?
          @buffer.delete(id)
        end
      else
        @buffer[id][topic] = rest
      end
    end

    def flush(id)
      topics = @buffer[id]
      if topics
        topics.each do |topic, buffer|
          self.puts(id, topic, buffer)
        end
        @buffer.delete(id)
      end
    end
  end

  class JobTree
    attr_accessor :concurrent
    attr_reader :is_root

    # @option is_root [Boolean]
    def initialize(is_root: false, concurrent: true)
      @concurrent = concurrent
      @is_root = is_root
      @tree = {}
      @jobs = []
    end

    def enqueue(env, cmd, command_args)
      segments = cmd[:command].split(".")
      enqueue_down(segments, env, cmd, command_args)
    end

    protected def enqueue_down(segments, env, cmd, command_args)
      segment, *segments = segments
      if @tree[segment]
        @tree[segment].enqueue_down(segments, env, cmd, command_args)
      else
        @jobs.push({
          env: env,
          cmd: cmd,
          args: command_args,
        })
      end
    end

    def each_chunk(&block)
      return to_enum(:each_chunk) unless block_given?

      @tree.keys.sort.each do |key|
        @tree[key].each_chunk(&block)
      end

      yield self, @jobs
    end

    def setup_groups(paths)
      paths.each do |path|
        unless path.empty?
          path2 = path.dup
          segment = path2.shift
          leaf = (@tree[segment] ||= JobTree.new(is_root: false, concurrent: true))
          if path2.empty?
            leaf.concurrent = false
          else
            leaf.setup_groups([path2])
          end
        end
      end
    end
  end

  class JobRunner
    attr_accessor :thread_limit
    attr_accessor :buffer_size
    attr_accessor :max_buffer_size
    attr_accessor :noop

    def initialize
      @noop = false
      @tree = JobTree.new(is_root: true, concurrent: true)
      @thread_limit = 1
      @buffer_size = 4096
      @max_buffer_size = 0x10000
    end

    def enqueue(env, cmd, command_args)
      @tree.enqueue(env, cmd, command_args)
    end

    # @param path [Array<Array<String>>]
    def setup_groups(paths)
      @tree.setup_groups(paths)
    end

    def run
      if @thread_limit > 0
        output = Queue.new
        pool = 1.upto(@thread_limit).map do |i|
          queue = Queue.new
          thread = Thread.new do
            # thread.abort_on_exception = true
            job_thread(i, queue, output)
          end
          {
            idx: i,
            in: queue,
            thread: thread,
          }
        end

        idx = 0
        @tree.each_chunk do |leaf, jobs|
          if leaf.concurrent
            # the jobs don't mind being executed in parallell, spread them across all available threads
            jobs.each do |job|
              pool[idx][:in].push([:exec, job])
              idx = (idx + 1) % pool.size
            end
          else
            # the jobs would prefer to execute in sequence, queue them all on a single thread
            input = pool[idx][:in]
            jobs.each do |job|
              input.push([:exec, job])
            end
            idx = (idx + 1) % pool.size
          end
        end
        pool.each do |item|
          item[:in].push([:exit])
        end

        result = []
        active_threads = pool.map do |row|
          row[:idx]
        end
        ui = UI.new(thread_limit: @thread_limit, max_buffer_size: @max_buffer_size)
        loop do
          if output.empty? && active_threads.empty?
            break
          end

          item = output.pop
          command, *args = item
          case command
          when :up
            id, = args
            # puts "THREAD(#{id}) IS UP"
          when :exec_start
            id, _env, cmd, _command_args = args
            ui.set_context(id, cmd[:command])
            ui.write(id, "EXEC", cmd[:command] + $/)
          when :exec_stderr
            id, blob = args
            ui.write(id, "STDERR", blob)
          when :exec_stdout
            id, blob = args
            ui.write(id, "STDOUT", blob)
          when :exec_resp
            id, exit_status, env, cmd, cmd_args = args
            ui.flush(id)
            result.push(CommandResult.new(exit_status: exit_status, env: env, cmd: cmd, args: cmd_args))
          when :exit
            id, reason = args
            # puts "THREAD(#{id}) HAS EXIT: #{reason}"
            active_threads.delete(id)
          end
        end

        pool.each do |item|
          item[:thread].join
        end
        result
      else
        fail "not enough threads to execute jobs"
      end
    end

    def job_thread(id, queue, output)
      output.push([:up, id])
      loop do
        item = queue.pop

        case item
        when Array
          command, *args = item
          case command
          when :exit
            output.push([:exit, id, :normal])
            break
          when :exec
            job, = args
            exec_job(id, job, output)
          else
            output.push([:exit, id, [:unexpected_command, item]])
            break
          end
        else
          raise "job runner received an item that was not an array: #{item.inspect}"
        end
      end
    rescue => ex
      output.push([:exit, id, ex])
      raise ex
    end

    def exec_job(id, job, output)
      env = job[:env]
      cmd = job[:cmd]
      command_args = job[:args]
      exit_status = nil
      if @noop
        # We'll just lie about it, bye bye
        exit_status = 0
      else
        e_read, e_write = IO.pipe()
        o_read, o_write = IO.pipe()
        begin
          output.push([:exec_start, id, env, cmd, command_args])
          pid = spawn(
            env,
            cmd[:path],
            *command_args,
            chdir: cmd[:dirname],
            out: o_write,
            err: e_write
          )

          readers = [e_read, o_read]
          loop do
            if exit_status
              break
            end

            if not exit_status
              _pid, status = Process.waitpid2(pid, Process::WNOHANG)
              if status
                exit_status = status.exitstatus
                break
              end
            end

            drain_io(id, e_read, o_read, output)
          end

          until readers.all?(&:closed?)
            break unless drain_io(id, e_read, o_read, output)
          end
        rescue SystemCallError => ex
          # Convert spawn/setup process errors into normal command failures.
          output.push([:exec_stderr, id, "#{ex.class}: #{ex.message}"])
          exit_status = 126
        rescue => ex
          output.push([:exec_stderr, id, "#{ex.class}: #{ex.message}"])
          exit_status = 1
        ensure
          e_read.close
          e_write.close
          o_read.close
          o_write.close
        end
      end
      output.push([:exec_resp, id, exit_status, env, cmd, command_args])
    end

    def drain_io(id, e_read, o_read, output)
      readers = []
      readers.push(e_read) unless e_read.closed?
      readers.push(o_read) unless o_read.closed?

      if readers.empty?
        return
      end

      ready, = select(readers, nil, nil, 0.1)
      if ready
        ready.each do |io|
          begin
            blob = io.read_nonblock(buffer_size)
            if io == e_read
              output.push([:exec_stderr, id, blob])
            elsif io == o_read
              output.push([:exec_stdout, id, blob])
            else
              fail "unexpected io device"
            end
          rescue IO::WaitReadable
          rescue EOFError
            io.close
          end
        end
        return true
      else
        return false
      end
    end
  end
end
