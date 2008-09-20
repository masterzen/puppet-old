require 'puppet'
require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    class ArithmeticOperator < AST::Branch

        attr_accessor :operator, :lval, :rval

        # Iterate across all of our children.
        def each
            [@lval,@rval,@operator].each { |child| yield child }
        end

        # Returns a boolean which is the result of the boolean operation
        # of lval and rval operands
        def evaluate(scope)
            # evaluate the operands, should return a boolean value
            lval = @lval.safeevaluate(scope)
            lval = lval.to_i
            rval = @rval.safeevaluate(scope)
            rval = rval.to_i

            unless lval.is_a?(Fixnum)
                raise ArgumentError, "%s is not an integer" % lval
            end

            unless rval.is_a?(Fixnum)
                raise ArgumentError, "%s is not an integer" % rval
            end

            # return result
            case @operator
            when "+";  lval + rval
            when "-";  lval - rval
            when "*";  lval * rval
            when "/";  lval / rval
            when "<<"; lval << rval
            when ">>"; lval >> rval
            end
        end

        def initialize(hash)
            super

            unless %w{+ - * / << >>}.include?(@operator)
                raise ArgumentError, "Invalid arithmetic operator %s" % @operator
            end
        end
    end
end
