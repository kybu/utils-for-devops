require "utils-for-devops/version"
require "childprocess"

module UtilsForDevops
  extend self

  def exec(cmd, wait: true)
    if cmd.kind_of? String
      cmd=[cmd]
    elsif not cmd.kind_of? Array
      raise "cmd argument should be an array!"
    end

    process = ChildProcess.build *cmd
    process.io.inherit!
    process.start

    if wait
      process.wait
      if process.exit_code != 0
        raise "'#{cmd.join ' '}' failed!"
      end
    end
  end

  def exec_wait(cmd, line: nil, line_occur: 1)
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

    if not line
      yield r
    else
      r.each_line do |l|
        puts l
        break if l =~ line
      end
    end

    Thread.new do
      loop { print r.readpartial(8192) } rescue EOFError
    end


    return process
  end
end
