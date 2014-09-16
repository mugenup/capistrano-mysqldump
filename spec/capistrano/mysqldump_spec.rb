require 'spec_helper'

describe Capistrano::Mysqldump do
  it 'has a version number' do
    expect(Capistrano::Mysqldump::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
