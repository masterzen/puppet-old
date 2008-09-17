
class Puppet::Parser::AST
    class BooleanOperator < AST::Branch

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
            rval = @rval.safeevaluate(scope)
            
            # return result
            case @operator
            when "and": Puppet::Parser::Scope.true?(rval) and Puppet::Parser::Scope.true?(lval)
            when "or": Puppet::Parser::Scope.true?(rval) or Puppet::Parser::Scope.true?(lval)
            end
        end

        def initialize(hash)
            super

            unless %w{and or}.include?(@operator)
                raise ArgumentError, "Invalid boolean operator %s" % @operator
            end
        end
    end
end
