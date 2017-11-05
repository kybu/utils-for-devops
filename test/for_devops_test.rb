require "test_helper"
require "awesome_print"

UtilsForDevops.configure log_level: Logger::DEBUG

class For::ForDevopsTest < Minitest::Test
  CURRDIR = File.dirname __FILE__
  RUBYEXE = "/proc/#{Process.pid}/exe"
  
  def exec(*args, &block)
    UtilsForDevops.exec *args, &block  
  end
  
  def exec_wait(*args, &block)
    UtilsForDevops.exec_wait *args, &block
  end

  def test_that_it_has_a_version_number
    refute_nil ::For::Devops::VERSION
  end

  def test_exec_simple
    exec ["ls"]
    exec "ls"
    exec "ls -l"

    assert_raises RuntimeError do exec "asdfsafsadf" end
    assert_raises ChildProcess::LaunchError do exec ["asdfsafsadf"] end

    exec %w"ls -F /", print_output: false
  end

  def test_exec_wait_simple
    exec_wait %w{ls -F /}, line: %r"^usr/$"

    exec_wait %w{ls -F /} do |r|
      r.each_line do |l|
        puts l
        break if l =~ %r"^usr/$"
      end
    end

    exec_wait %W{#{RUBYEXE} #{CURRDIR}/generdata.rb --print-words},
              line: /word1/, line_occur: 1
    exec_wait %W{#{RUBYEXE} #{CURRDIR}/generdata.rb --print-words},
              line: /word1/, line_occur: 2
    exec_wait %W{#{RUBYEXE} #{CURRDIR}/generdata.rb --print-words},
              line: /end word7/
  end

  def test_exec_wait_extract
    match = exec_wait %w{ls -F /}, extract: %r"^(usr)/"

    assert_kind_of MatchData, match
    assert_equal 'usr', match[1]

    process, match = exec_wait %w{ls -F /},
                               extract: %r"^(usr)/",
                               return_process: true

    assert_kind_of ChildProcess::AbstractProcess, process
    assert_kind_of MatchData, match
    assert_equal 'usr', match[1]
  end

  def test_exec_lots_data
    # Not much of a test. Output is redirected to /dev/null
    exec %W{#{RUBYEXE} #{CURRDIR}/generdata.rb -s 1024 --line-sleep},
         print_output: false
  end

  def test_exec_wait_lots_data
    cmd = %W{#{RUBYEXE} #{CURRDIR}/generdata.rb -s 1024 --line-sleep --beginning-line blablabla}

    prcs = []
    5.times { prcs.push(exec_wait cmd, line: /blablabla/) }

    prcs.each {|p| p.wait}
  end
end
