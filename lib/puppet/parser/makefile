#parser.rb: grammar.ry
#	ryacc --output parser grammar

parser.rb: grammar.ra
	racc -g -o$@ grammar.ra

grammar.output: grammar.ra
	racc -v -o$@ grammar.ra
