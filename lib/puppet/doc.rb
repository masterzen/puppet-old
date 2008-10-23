
class Puppet::Doc

    def self.write_doc(outputdir, name, doc)
        f = File.new(File.join(outputdir,"#{name}.html"), "w")
        require 'rdiscount'
        markdown = RDiscount.new(doc)
        f.puts("<html><body>")
        f.puts(markdown.to_html)
        f.puts("</body></html>")
    end

    def self.parse(outputdir, manifest)
        parser = Puppet::Parser::Parser.new(:environment => "development")
        parser.file = manifest
        ast = parser.parse

        if manifest =~ /([^\/]+)\/manifests\/[^\/]+\.pp/
            module_name = $1
            outputdir = File.join(outputdir,module_name)
        end

        unless module_name.nil?
            Dir.mkdir(outputdir) unless FileTest.directory?(outputdir)
        end

        ast[:classes].each do |name, klass|
            self.write_doc(outputdir, name, klass.doc) unless name.empty?
        end

        ast[:definitions].each do |name, define|
            self.write_doc(outputdir, name, define.doc) unless name.empty?
        end
    end


    def self.doc(outputdir, files)
        # if outputdir is omitted
        outputdir ||= "doc"
        Dir.mkdir(outputdir) unless FileTest.directory?(outputdir)

        # scan every files from files, if directory descend
        manifests = []
        files.each do |file|
            if FileTest.directory?(file)
                files.concat(Dir.glob(File.join(file, "*")))
            elsif file =~ /\.pp$/ # got a manifest
                manifests << file
            end
        end

        # parse and document
        environment = "development"
        manifests.each do |manifest|
            self.parse(outputdir, manifest)
            # if we have a module, produce a module directory
            # then a file per class and per defines
        end
    end

    # launch a rdoc documenation process
    # with the files/dir passed in +files+
    def self.rdoc(outputdir, files)
        begin
            # load our parser first
            require 'puppet/rdoc/parser'

            # then rdoc
            require 'rdoc/rdoc'
            r = RDoc::RDoc.new
            RDoc::RDoc::GENERATORS["puppet"] = RDoc::RDoc::Generator.new("puppet/rdoc/generators/puppet_generator.rb",
                                                                       "PuppetGenerator".intern,
                                                                       "puppet")
            # specify our own format
            options = ["--fmt", "puppet"]

            # where to save the result
            options = ["--op", outputdir]
            options += files

            # launch the documentation process
            r.document(options)
        rescue RDoc::RDocError => e
            raise Puppet::ParseError.new("RDoc error %s" % e)
        end
    end
end