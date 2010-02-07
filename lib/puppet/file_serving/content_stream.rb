#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/content'

# A class that handles retrieving file contents.
# It only reads the file when its content is specifically
# asked for.
class Puppet::FileServing::ContentStream < Puppet::FileServing::Content

    def self.create(content)
        instance = new("/this/is/a/fake/path")
        instance.content = content
        instance
    end

    def self.from_raw(content)
        content
    end
end
