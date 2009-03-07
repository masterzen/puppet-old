require 'puppet'
require 'puppet/parser/ast/branch'
require 'puppet/parser/collector'

# An object that collects stored objects from the central cache and returns
# them to the current host, yo.
class Puppet::Parser::AST
class Collection < AST::Branch
    attr_accessor :type, :query, :form
    attr_reader :override

    associates_doc

    # We return an object that does a late-binding evaluation.
    def evaluate(scope)
        if self.query
            str, code = self.query.safeevaluate scope
        else
            str = code = nil
        end

        newcoll = Puppet::Parser::Collector.new(scope, @type, str, code, self.form)

        scope.compiler.add_collection(newcoll)

        add_override(newcoll, scope) if @override

        newcoll
    end

    # Handle our parameter ourselves
    def override=(override)
        if override.is_a?(AST::ASTArray)
            @override = override
        else
            @override = AST::ASTArray.new(
                :line => override.line,
                :file => override.file,
                :children => [override]
            )
        end
    end

    def add_override(collection, scope)
        params = @override.collect do |param|
            param.safeevaluate(scope)
        end

        collection.add_override(
            :params => params,
            :file => @file,
            :line => @line,
            :source => scope.source,
            :scope => scope
        )
    end

end
end
