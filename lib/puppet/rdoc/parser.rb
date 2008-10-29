# Puppet "parser" for the rdoc system


# rdoc mandatory includes
require "rdoc/code_objects"
require "rdoc/tokenstream"
require "rdoc/markup/simple_markup/preprocess"
require "rdoc/parsers/parserfactory"

module RDoc

class Parser
    extend ParserFactory

    parse_files_matching(/\.pp$/)

    def initialize(top_level, file_name, content, options, stats)
        @options = options
        @stats   = stats
        @input_file_name = file_name
        @top_level = top_level
        @progress = $stderr unless options.quiet
    end

    def scan
        # scan 
        environment = "development"
        @parser = Puppet::Parser::Parser.new(:environment => environment)
        @parser.file = @input_file_name
        @ast = @parser.parse
        scan_top_level(@top_level)
        @top_level
    end

    # walk down the namespace and lookup/create container as needed
    def get_class_or_module(container, name)

        # class ::A -> A is in the top level
        if name =~ /^::/
            container = @top_level
        end

        names = name.split('::')

        final_name = names.pop
        names.each do |name|
            prev_container = container
            container = container.find_module_named(name)
            if !container
              container = prev_container.add_module(NormalClass, name)
            end
        end
        return [container, final_name]
    end

    # create documentation
    def scan_top_level(container)

        comment = "" #  TODO will look into README
        look_for_directives_in(container, comment)
        container.comment = comment unless comment.empty?

        # infer module name from directory
        if @input_file_name =~ /([^\/]+)\/manifests\/.+\.pp/
            name = $1
        end

        puts "scanning module %s" % name

        mod = container.add_module(NormalModule, name)
        mod.record_location(@top_level)
        puts "adding file_relative_name %s" % name
        @top_level.file_relative_name = name

        parse_elements(mod)
    end

    def scan_for_include(container, code)
        code.each do |stmt|
            puts "stmt: %s" % stmt.inspect
            scan_for_include(container,code) if stmt.is_a?(Puppet::Parser::AST::ASTArray)

            if stmt.is_a?(Puppet::Parser::AST::Function) and stmt.name == "include"
                stmt.arguments.each do |included|
                    puts "included %s" % included.inspect
                    container.add_include(Include.new(included.value, stmt.doc))
                end
            end
        end
    end

    # create documentation for a class
    def document_class(name, klass, container)
        container, name = get_class_or_module(container, name)

        superclass = klass.parentclass
        superclass = "" if superclass.nil? or superclass.empty?

        @stats.num_classes += 1
        comment = klass.doc
        look_for_directives_in(container, comment) unless comment.empty?
        cls = container.add_class(NormalClass, name, superclass)
        cls.record_location(@top_level)

        # scan class code for include
        code = [klass.code] unless klass.code.is_a?(Puppet::Parser::AST::ASTArray)
        scan_for_include(cls, code) unless code.nil?

        cls.comment = comment
    end

    # create documentation for a define
    def document_define(name, define, container)
        # find superclas if any
        @stats.num_methods += 1

        # find the parentclass
        # split define name by :: to find the complete module hierarchy
        container, name = get_class_or_module(container,name)

        # build up declaration
        declaration = ""
        define.arguments.each do |arg,value|
            declaration << arg
            unless value.nil?
                declaration << " => "
                declaration << "#{value.value}"
            end
            declaration << ", "
        end
        declaration.chop!.chop! if declaration.size > 1

        # register method into the container
        meth =  AnyMethod.new(declaration, name)
        container.add_method(meth)
        meth.comment = define.doc
        meth.params = "( " + declaration + " )"
        meth.visibility = :public
        meth.document_self = true
        meth.singleton = false
    end

    def parse_elements(container)
        @ast[:classes].each do |name, klass|
            document_class(name,klass,container) unless name.empty?
        end

        @ast[:definitions].each do |name, define|
            document_define(name,define,container)
        end
    end

    def look_for_directives_in(context, comment)
        preprocess = SM::PreProcess.new(@input_file_name, @options.rdoc_include)

        preprocess.handle(comment) do |directive, param|
            case directive
            when "stopdoc"
                context.stop_doc
                ""
            when "startdoc"
                context.start_doc
                context.force_documentation = true
                ""
            when "enddoc"
                #context.done_documenting = true
                #""
                throw :enddoc
            when "main"
                options = Options.instance
                options.main_page = param
                ""
            when "title"
                options = Options.instance
                options.title = param
                ""
            when "section"
                context.set_current_section(param, comment)
                comment.replace("") # 1.8 doesn't support #clear
                break
            else
                warn "Unrecognized directive '#{directive}'"
                break
            end
        end
        remove_private_comments(comment)
    end

    def remove_private_comments(comment)
        comment.gsub!(/^#--.*?^#\+\+/m, '')
        comment.sub!(/^#--.*/m, '')
    end
end
end