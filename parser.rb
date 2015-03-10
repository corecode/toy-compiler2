require 'parslet'
require 'parslet/convenience'

class Parser < Parslet::Parser
  rule(:expr) { (atom | list) >> space? }
  rule(:list) { str('(') >> space? >> expr.repeat.as(:list) >> str(')') }
  rule(:atom) { integer | symbol }
  # we add symbol.absent? to prevent "123foo" to be parsed as integer 123, symbol foo.
  rule(:integer) { (match['+-'].maybe >> match['0-9'].repeat(1)).as(:integer) >> symbol.absent? }
  rule(:symbol) { (special.absent? >> match['[:graph:]']).repeat(1).as(:symbol) }
  rule(:special) { match['();'] }
  rule(:space?) { (space | comment).repeat }
  # we need a repeat(1) here to prevent a repetition of epsilon
  rule(:space) { match('\s').repeat(1) }
  # the space rule will eat the newline
  rule(:comment) { str(';') >> match['^\r\n'].repeat }
  rule(:document) { space? >> expr.repeat.as(:list) }
  root(:document)
end

if $0 == __FILE__
  puts Parser.new.parse_with_debug($stdin.read)
end
