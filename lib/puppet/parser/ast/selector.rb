require 'puppet/parser/ast/branch'

class Puppet::Parser::AST
    # The inline conditional operator.  Unlike CaseStatement, which executes
    # code, we just return a value.
    class Selector < AST::Branch
        attr_accessor :param, :values

        def each
            [@param,@values].each { |child| yield child }
        end

        # Find the value that corresponds with the test.
        def evaluate(scope)
            retvalue = nil
            found = nil

            # Get our parameter.
            paramvalue = @param.safeevaluate(scope)

            sensitive = Puppet[:casesensitive]

            if ! sensitive and paramvalue.respond_to?(:downcase)
                paramvalue = paramvalue.downcase
            end

            default = nil

            unless @values.instance_of? AST::ASTArray or @values.instance_of? Array
                @values = [@values]
            end

            # Then look for a match in the options.
            @values.each { |obj|
                if obj.param.evaluate_match(paramvalue, scope, :file => file, :line => line, :sensitive => sensitive)
                    # we found a matching option
                    begin
                        retvalue = obj.value.safeevaluate(scope)
                    ensure
                        scope.unset_ephemeral_var
                    end
                    found = true
                    break
                elsif obj.param.is_a?(Default)
                    # Store the default, in case it's necessary.
                    default = obj
                end
            }

            # Unless we found something, look for the default.
            unless found
                if default
                    retvalue = default.value.safeevaluate(scope)
                else
                    self.fail Puppet::ParseError,
                        "No matching value for selector param '%s'" % paramvalue
                end
            end

            return retvalue
        end
    end
end
