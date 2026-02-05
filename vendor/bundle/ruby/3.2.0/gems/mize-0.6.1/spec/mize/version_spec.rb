require 'spec_helper'

describe 'Mize::VERSION' do
  it 'has a version' do
    expect(Mize::VERSION).to be_a String
    expect(Mize::VERSION).to match(/\d+./)
  end
end
