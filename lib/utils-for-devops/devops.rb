require "utils-for-devops/version"
require "childprocess"

module UtilsForDevops
  extend self

  def exec(cmd, wait: true, print_output: true)
    if cmd.kind_of? String
      cmd=[cmd]
    elsif not cmd.kind_of? Array
      raise "cmd argument should be an array!"
    end

    process = ChildProcess.build *cmd
    if print_output
      process.io.inherit!
      process.start
    else
      process.io.stdout = process.io.stderr = File.open '/dev/null', 'w'
      process.io._stdin = File.open '/dev/null', 'r'

      process.start
      process.io.stdout.close
    end

    if wait
      process.wait
      if process.exit_code != 0
        raise "'#{cmd.join ' '}' failed!"
      end
    end
  end

  def exec_wait(cmd,
                print_output: true,
                line: nil, line_occur: 1,
                extract: nil, return_process: false,
                kill: false)

    if cmd.kind_of? String
      cmd=[cmd]
    elsif not cmd.kind_of? Array
      raise "cmd argument should be an array!"
    end

    r, w = IO.pipe
    w.sync
    r.sync
    process = ChildProcess.build *cmd
    process.io.stdout = process.io.stderr = w
    process.start
    w.close

    consumeOutput = lambda do
      Thread.new do
        loop { r.readpartial(8192) } rescue EOFError
      end
    end

    if !line && !extract
      yield r

    elsif extract
      m = nil

      r.each_line do |l|
        puts l if print_output

        if (m = l.match extract)
          if kill
            process.stop
          else
            consumeOutput
          end

          return [process, m] if return_process
          return m
        end
      end

    else
      r.each_line do |l|
        puts l if print_output

        if l =~ line
          if kill
            process.stop
          else
            consumeOutput
          end

          return process
        end
      end
    end
  end
end
