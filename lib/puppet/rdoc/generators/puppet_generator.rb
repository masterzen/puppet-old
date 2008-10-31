require 'rdoc/generators/html_generator'
module Generators

    MODULE_DIR = "modules"

    # This is a special HTMLGenerator tailored to Puppet manifests
    class PuppetGenerator < HTMLGenerator

        def PuppetGenerator.for(options)
            AllReferences::reset
            HtmlMethod::reset

            if options.all_one_file
                PuppetGeneratorInOne.new(options)
            else
                PuppetGenerator.new(options)
            end
        end

        def initialize(options) #:not-new:
            @options    = options
            load_html_template
        end

        def load_html_template
            begin
                require 'puppet/rdoc/generators/template/puppet/puppet'
                extend RDoc::Page
            rescue LoadError
                $stderr.puts "Could not find Puppet template '#{template}'"
                exit 99
            end
        end

        def gen_method_index
            # we don't generate an all define index
            # as the presentation is per module/per class
        end

        ##
        # Generate:
        #  the list of modules
        #  the list of classes and defines of a specific module
        #  the list of all classes
        def build_indices
            @allfiles = []

            # contains all the seen modules
            @modules = {}
            @allclasses = {}

            # build the modules, classes and per modules classes and define list
            @toplevels.each do |toplevel|
                file = HtmlFile.new(toplevel, @options, FILE_DIR)
                classes = []
                methods = []
                modules = []

                # find all classes of this toplevel
                # store modules if we find one
                toplevel.each_classmodule do |k|
                    generate_class_list(classes, modules, k, toplevel, CLASS_DIR)
                end

                # find all defines belonging to this toplevel
                HtmlMethod.all_methods.each do |m|
                    # find parent module, check this method is not already
                    # defined.
                    if m.context.parent.toplevel === toplevel
                        methods << m
                    end
                end

                classes.each do |k|
                    @allclasses[k.index_name] = k if !@allclasses.has_key?(k.index_name)
                end

                @files << file
                @allfiles << { "file" => file, "modules" => modules, "classes" => classes, "methods" => methods }
            end

            @classes = @allclasses.values
        end

        def generate_class_list(classes, modules, from, html_file, class_dir)
            if from.is_module? and !@modules.has_key?(from.name)
                k = HtmlClass.new(from, html_file, class_dir, @options)
                classes << k
                @modules[from.name] = k
                modules << @modules[from.name]
            elsif from.is_module?
                modules << @modules[from.name]
            elsif !from.is_module?
                k = HtmlClass.new(from, html_file, class_dir, @options)
                classes << k
            end
            from.each_classmodule do |mod|
                generate_class_list(classes, modules, mod, html_file, class_dir)
            end
        end

        # generate all the subdirectories, modules, classes and files
        def gen_sub_directories
            begin
                super
                File.makedirs(MODULE_DIR)
            rescue
                $stderr.puts $!.message
                exit 1
            end
        end

        # generate the index of modules
        def gen_file_index
            gen_top_index(@modules.values, 'All Modules', RDoc::Page::TOP_INDEX, "fr_modules_index.html")
        end

        # generate a top index
        def gen_top_index(collection, title, template, filename)
            template = TemplatePage.new(RDoc::Page::FR_INDEX_BODY, template)
            res = []
            collection.sort.each do |f|
                if f.document_self
                    res << { "classlist" => "#{MODULE_DIR}/fr_#{f.index_name}.html", "module" => "#{CLASS_DIR}/#{f.index_name}.html","name" => f.index_name }
                end
            end

            values = {
                "entries"    => res,
                'list_title' => CGI.escapeHTML(title),
                'index_url'  => main_url,
                'charset'    => @options.charset,
                'style_url'  => style_url('', @options.css),
            }

            File.open(filename, "w") do |f|
                template.write_html_on(f, values)
            end
        end

        # generate the all class index file and the combo index
        def gen_class_index
            gen_an_index(@classes, 'All Classes', RDoc::Page::CLASS_INDEX, "fr_class_index.html")
            @allfiles.each do |file|
                gen_composite_index(file["classes"],file["methods"], file['modules'], 'Classes', 'Defines',
                                    RDoc::Page::COMBO_INDEX,
                                    "#{MODULE_DIR}/fr_#{file["file"].context.file_relative_name}.html")
            end
        end

        def gen_composite_index(coll1, coll2, coll3, title1, title2, template, filename)
            template = TemplatePage.new(RDoc::Page::FR_INDEX_BODY, template)
            res1 = []
            coll1.sort.each do |f|
                if f.document_self
                    unless f.context.is_module?
                        res1 << { "href" => "../"+f.path, "name" => f.index_name }
                    end
                end
            end

            res2 = []
            coll2.sort.each do |f|
                if f.document_self
                    res2 << { "href" => "../"+f.path, "name" => f.index_name.sub(/\(.*\)$/,'') }
                end
            end

            module_name = []
            coll3.sort.each do |f|
                module_name << { "href" => "../"+f.path, "name" => f.index_name }
            end

            values = {
                "module" => module_name,
                "entries1"    => res1,
                'list_title1' => CGI.escapeHTML(title1),
                "entries2"    => res2,
                'list_title2' => CGI.escapeHTML(title2),
                'index_url'  => main_url,
                'charset'    => @options.charset,
                'style_url'  => style_url('', @options.css),
            }

            File.open(filename, "w") do |f|
                template.write_html_on(f, values)
            end
        end

        # returns the initial_page url
        def main_url
            main_page = @options.main_page
            ref = nil
            if main_page
                ref = AllReferences[main_page]
                if ref
                    ref = ref.path
                else
                    $stderr.puts "Could not find main page #{main_page}"
                end
            end

            unless ref
                for file in @files
                    if file.document_self
                        ref = "#{CLASS_DIR}/#{file.index_name}.html"
                        break
                    end
                end
            end

            unless ref
                $stderr.puts "Couldn't find anything to document"
                $stderr.puts "Perhaps you've used :stopdoc: in all classes"
                exit(1)
            end

            ref
        end
    end

    class PuppetGeneratorInOne < HTMLGeneratorInOne
        def gen_method_index
            gen_an_index(HtmlMethod.all_methods, 'Defines')
        end
    end

 end