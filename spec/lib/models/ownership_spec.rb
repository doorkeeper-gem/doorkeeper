require 'spec_helper'
require 'active_record'
require 'active_record/associations'
require 'doorkeeper/models/ownership'

describe 'Ownership' do
  subject do
    Class.new do
      extend ActiveRecord::Association
      include ActiveModel::Validations
      include Doorkeeper::Models::Ownership
    end.new
  end

end
