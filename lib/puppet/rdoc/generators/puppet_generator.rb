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

    end

    class PuppetGeneratorInOne < HTMLGeneratorInOne
        def gen_method_index
          gen_an_index(HtmlMethod.all_methods, 'Defines')
        end
    end

end