require 'rdoc/generators/html_generator'
module Generators
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
          gen_an_index(HtmlMethod.all_methods, 'Defines',
                       RDoc::Page::METHOD_INDEX,
                       "fr_method_index.html")
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
          @toplevels.each do |toplevel|
            @files << HtmlFile.new(toplevel, @options, FILE_DIR)
          end

          RDoc::TopLevel.all_classes_and_modules.each do |cls|
              puts "class: %s" % cls.full_name
            build_class_list(cls, @files[0], CLASS_DIR)
          end
        end

        def build_class_list(from, html_file, class_dir)
            puts "bcl: %s" % from.full_name
          @classes << HtmlClass.new(from, html_file, class_dir, @options)
          from.each_classmodule do |mod|
              puts "bcl from: %s" % mod.full_name
            build_class_list(mod, html_file, class_dir)
          end
        end

        def gen_file_index
          gen_an_index(@files, 'Modules', 
                       RDoc::Page::FILE_INDEX, 
                       "fr_modules_index.html")
        end

        def gen_class_index
          gen_composite_index(@classes, HtmlMethod.all_methods, 'Classes', 'Defines',
                       RDoc::Page::COMBO_INDEX,
                       "fr_combo_index.html")
        end

        def gen_composite_index(coll1, coll2, title1, title2, template, filename)
          template = TemplatePage.new(RDoc::Page::FR_INDEX_BODY, template)
          res1 = []
          coll1.sort.each do |f|
            if f.document_self
              res1 << { "href" => f.path, "name" => f.index_name }
            end
          end

          res2 = []
          coll2.sort.each do |f|
            if f.document_self
              res2 << { "href" => f.path, "name" => f.index_name }
            end
          end

          values = {
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