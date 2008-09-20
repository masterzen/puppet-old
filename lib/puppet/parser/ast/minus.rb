require 'puppet'
require 'puppet/parser/ast/branch'

# An object that returns a boolean which is the boolean not
# of the given value.
class Puppet::Parser::AST
    class Minus < AST::Branch
        attr_accessor :value

        def each
            yield @value
        end

        def evaluate(scope)
            val = @value.safeevaluate(scope)
            val = val.to_i
            unless val.is_a?(Fixnum)
                raise ArgumentError, "%s is not an integer" % val
            end
            return -val
        end
    end
end
