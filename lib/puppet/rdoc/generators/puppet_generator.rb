require 'rdoc/generators/html_generator'
module Generators

    MODULE_DIR = "modules"

    class PuppetGenerator < HTMLGenerator

        # Generators may need to return specific subclasses depending
        # on the options they are passed. Because of this
        # we create them using a factory

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
          require 'puppet/rdoc/generators/template/puppet/puppet'
          extend RDoc::Page
        rescue LoadError
          $stderr.puts "Could not find HTML template '#{template}'"
          exit 99
        end

        def gen_method_index
            HtmlMethod.all_methods.each do |m|
                puts "m %s %s" % [m.name, m.aref]
            end
          # gen_an_index(HtmlMethod.all_methods, 'Defines',
          #              RDoc::Page::METHOD_INDEX,
          #              "fr_method_index.html")
        end

        ##
        # Generate:
        #
        # * a list of HtmlFile objects for each TopLevel object.
        # * a list of HtmlClass objects for each first level
        #   class or module in the TopLevel objects
        # * a complete list of all hyperlinkable terms (file,
        #   class, module, and method names)

        def build_indices
            @allfiles = []
          @toplevels.each do |toplevel|
              puts "for toplevel %s" % toplevel
              file = HtmlFile.new(toplevel, @options, FILE_DIR)
              classes = []
              methods = []
              toplevel.each_classmodule do |k|
                  generate_class_list(classes, k, toplevel, CLASS_DIR)
              end
              HtmlMethod.all_methods.each do |m|
                  if m.context.parent.toplevel == toplevel
                      puts "m %s %s" % [m.name, m.aref]
                      methods << m
                  end
              end
              @classes += classes
              @files << file
            @allfiles << { "file" => file,  "classes" => classes, "methods" => methods }
          end
          # RDoc::TopLevel.all_classes_and_modules.each do |cls|
          #   build_class_list(cls, @files[0], CLASS_DIR)
          # end

        end

        def generate_class_list(classes, from, html_file, class_dir)
          classes << HtmlClass.new(from, html_file, class_dir, @options)
          from.each_classmodule do |mod|
            generate_class_list(classes, mod, html_file, class_dir)
          end
        end

        def build_class_list(from, html_file, class_dir)
          @classes << HtmlClass.new(from, html_file, class_dir, @options)
          from.each_classmodule do |mod|
            build_class_list(mod, html_file, class_dir)
          end
        end

        def gen_sub_directories
            super
          File.makedirs(MODULE_DIR)
        rescue 
          $stderr.puts $!.message
          exit 1
        end

        def gen_file_index
          gen_top_index(@files, 'All Modules',
                       RDoc::Page::FILE_INDEX,
                       "fr_modules_index.html")
        end

        def gen_top_index(collection, title, template, filename)
          template = TemplatePage.new(RDoc::Page::FR_INDEX_BODY, template)
          res = []
          collection.sort.each do |f|
            if f.document_self
              res << { "href" => "#{MODULE_DIR}/fr_#{f.index_name}.html", "name" => f.index_name }
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

        def gen_class_index
            gen_an_index(@classes, 'All Classes',
                         RDoc::Page::CLASS_INDEX,
                         "fr_class_index.html")
            @allfiles.each do |file|
          gen_composite_index(file["classes"],file["methods"], 'Classes', 'Defines',
                       RDoc::Page::COMBO_INDEX,
                       "#{MODULE_DIR}/fr_#{file["file"].context.file_relative_name}.html")
                   end
        end

        def gen_composite_index(coll1, coll2, title1, title2, template, filename)
          template = TemplatePage.new(RDoc::Page::FR_INDEX_BODY, template)
          res1 = []
          module_name = []
          coll1.sort.each do |f|
            if f.document_self
                if f.context.is_module?
                    module_name << { "href" => "../"+f.path, "name" => f.index_name }
                else
                    res1 << { "href" => "../"+f.path, "name" => f.index_name }
                end
            end
          end

          res2 = []
          coll2.sort.each do |f|
            if f.document_self
                puts "combo f: %s %s" % [f.name,f.aref]
              res2 << { "href" => "../"+f.path, "name" => f.index_name.sub(/\(.*\)$/,'') }
            end
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
    end

    class PuppetGeneratorInOne < HTMLGeneratorInOne
        def gen_method_index
          gen_an_index(HtmlMethod.all_methods, 'Defines')
        end
    end

 end