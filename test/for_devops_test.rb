require "test_helper"

class For::ForDevopsTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::For::Devops::VERSION
  end

  def test_exec_simple
    UtilsForDevops.exec ["ls"]
    UtilsForDevops.exec "ls"

    assert_raises ChildProcess::LaunchError do UtilsForDevops.exec "ls -l" end

    UtilsForDevops.exec %w"ls -F /", print_output: false
  end

  def test_exec_wait_simple
    UtilsForDevops.exec_wait %w{ls -F /}, line: %r"^usr/$"

    UtilsForDevops.exec_wait %w{ls -F /} do |r|
      r.each_line do |l|
        puts l
        break if l =~ %r"^usr/$"
      end
    end
  end

  def test_exec_wait_extract
    match = UtilsForDevops.exec_wait %w{ls -F /}, extract: %r"^(usr)/"

    assert_kind_of MatchData, match
    assert_equal 'usr', match[1]

    process, match = UtilsForDevops.exec_wait %w{ls -F /},
                                              extract: %r"^(usr)/",
                                              return_process: true

    assert_kind_of ChildProcess::AbstractProcess, process
    assert_kind_of MatchData, match
    assert_equal 'usr', match[1]
  end
end
