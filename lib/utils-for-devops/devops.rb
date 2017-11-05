require "utils-for-devops/version"
require "childprocess"
require 'thread'
require 'logger'

module UtilsForDevops
  extend self

  # TODO process_detach, detect shell
  def configure(log_level: Logger::FATAL, shell: '/bin/bash')
    @@log = Logger.new(STDOUT)
    @@log.level = log_level
    @@shell = shell
  end

  def exec(cmd, wait: true, print_output: true)
    if cmd.kind_of? String
      cmd=%W"#{@@shell} -c #{cmd}"
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

  @@mtx = Mutex.new
  @@consumingPrcs = []
  @@outputConsumingThr = nil
  @@notif = nil

  def exec_wait(cmd,
                print_output: true,
                line: nil, line_occur: 1,
                extract: nil, return_process: false,
                kill: false)

    if cmd.kind_of? String
      cmd=%W"#{@@shell} -c #{cmd}"
    elsif not cmd.kind_of? Array
      raise "cmd argument should be an array!"
    end

    r, w = IO.pipe
    w.sync
    r.sync
    process = ChildProcess.build *cmd
    process.io.stdout = process.io.stderr = w
    process.detach
    process.start
    w.close

    procInfo = Struct.new(:process, :readIO)

    consumeOutput = lambda do |prcs, readIO|
      @@mtx.synchronize do

        # There is no process, for which its output is consumed. Initialize the
        # consuming thread, etc ...
        if @@outputConsumingThr.nil?
          @@notif = IO.pipe.map {|i| i.sync; i}
          @@consumingPrcs.push procInfo.new(nil, @@notif[0])

          # Just one thread is used to consume output from all executed processes
          @@outputConsumingThr = Thread.new do
            while true
              begin
                prcs = []
                @@mtx.synchronize do
                  prcs = @@consumingPrcs.map{|p| p.readIO}
                end

                toRead = IO.select prcs
                # TODO handle stderr
                toRead[0].each do |r|
                  begin
                    # Default pipe buffer size on linux is 64kB. My debian has 1MB.
                    buf = r.readpartial 65536

                    if @@notif[0] == r
                      @@log.debug "New output to consume added."
                    else
                      @@log.debug "Output consumed: #{buf.size}B"
                    end
                  rescue EOFError
                    @@log.debug "EOFError when consuming outputs"
                    afterCount, beforeCount = nil, @@consumingPrcs.size

                    @@mtx.synchronize { @@consumingPrcs.delete_if{|p| p.readIO == r} ; afterCount = @@consumingPrcs.size}

                    @@log.debug "Consuming processes clean-up, before/after: #{beforeCount}/#{afterCount}"
                  end
                end

              rescue e
                @@log.error e.message
              end
            end
          end
        end

        @@consumingPrcs.push procInfo.new(prcs, readIO)
        @@notif[1].write '1'
      end
    end

    if !line && !extract
      yield r

    elsif extract
      r.each_line do |l|
        puts l if print_output

        if (m = l.match extract)
          if kill
            process.stop
          else
            consumeOutput.call process, r
          end

          return [process, m] if return_process
          return m
        end
      end

    else
      linesMatched = 0

      r.each_line do |l|
        puts l if print_output

        if l =~ line and (linesMatched+=1) >= line_occur
          if kill
            process.stop
          else
            consumeOutput.call process, r
          end

          return process
        end
      end
    end
  end
end
