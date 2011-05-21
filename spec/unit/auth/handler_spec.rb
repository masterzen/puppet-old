#!/usr/bin/env rspec

require 'spec_helper'

require 'puppet/auth'
require 'puppet/auth/handler'
require 'puppet/network/http'

describe Puppet::Auth::Handler do
  describe "when included" do
    it "should include the correct sub-handler" do
      handler = Class.new() do
        def self.name
          "Puppet::Network::HTTP::MongrelREST"
        end
      end
      handler.send(:include, Puppet::Auth::Handler)

      handler.should be_include(Puppet::Auth::MongrelSsl)
    end
  end
end
