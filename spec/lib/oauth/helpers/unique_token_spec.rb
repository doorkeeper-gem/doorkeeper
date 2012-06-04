require 'spec_helper'
require 'doorkeeper/oauth/helpers/unique_token'

module Doorkeeper::OAuth::Helpers
  describe UniqueToken do
    let :generator do
      lambda { |size| "a" * size }
    end

    it "is able to customize the generator method" do
      token = UniqueToken.generate(:generator => generator)
      token.should == "a" * 32
    end

    it "is able to customize the size of the token" do
      token = UniqueToken.generate(:generator => generator, :size => 2)
      token.should == "aa"
    end
  end
end
