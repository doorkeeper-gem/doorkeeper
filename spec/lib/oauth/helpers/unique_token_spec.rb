require 'spec_helper'
require 'doorkeeper/oauth/helpers/unique_token'

module Doorkeeper::OAuth::Helpers
  describe UniqueToken do
    let(:klass) { mock }

    let :generator do
      lambda { |size| "a" * size }
    end

    it "finds in the collection with given attribute" do
      klass.should_receive(:find_by_attribute).and_return(nil)
      UniqueToken.generate_for(:attribute, klass, :generator => generator)
    end

    it "is able to customize the generator method" do
      klass.stub(:find_by_attribute).and_return(nil)
      token = UniqueToken.generate_for(:attribute, klass, :generator => generator)
      token.should == "a" * 32
    end

    it "is able to customize the size of the token" do
      klass.stub(:find_by_attribute).and_return(nil)
      token = UniqueToken.generate_for(:attribute, klass, :generator => generator, :size => 2)
      token.should == "aa"
    end

    it "reattempt to create a token if has already found one" do
      existing_tokens  = ["a"*32, nil]
      attempted_tokens = ["a"*32, "b"]
      generator        = lambda { |size| attempted_tokens.pop }
      klass.stub(:find_by_attribute) { existing_tokens.pop }
      token = UniqueToken.generate_for(:attribute, klass, :generator => generator)
      token.should == "b"
    end
  end
end
