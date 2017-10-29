require 'getoptlong'
require 'benchmark'
require 'securerandom'

opts = GetoptLong.new(
  # Generated data size in kB
  [ '--size', '-s', GetoptLong::REQUIRED_ARGUMENT ],
  # Sleep between line prints
  ['--line-sleep', GetoptLong::NO_ARGUMENT],
  ['--print-words', GetoptLong::NO_ARGUMENT],
  ['--beginning-line', GetoptLong::REQUIRED_ARGUMENT])

dataSize = 1
lineSleep = false
beginLine = nil

opts.each do |opt, arg|
  case opt
    when '--size'
      dataSize=arg.to_i
    when '--line-sleep'
      lineSleep = true
    when '--beginning-line'
      beginLine = arg.to_s
    when '--print-words'
      puts <<BLA
word1
word2
word3
word1
word4 word5
word6
word2 word3
end word7
BLA
      exit 0
  end
end

dataSize *= 1024
generatedSize = 0

puts Benchmark.measure {
  generatedLines = 0
  rnd = Random.new

  while generatedSize < dataSize
    begin
      if beginLine and generatedLines == 15
        puts beginLine
        next
      end

      puts (line=SecureRandom.hex(rnd.rand 63))
      generatedSize += line.size+1
      sleep rnd.rand(0.003) if lineSleep and (rnd.rand(3)%3!=1)

    ensure
      generatedLines+=1
    end
  end
}
