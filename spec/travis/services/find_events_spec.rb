require 'spec_helper'

describe Travis::Services::FindEvents do
  include Support::ActiveRecord

  let(:repo)    { create(:repository, :owner_name => 'travis-ci', :name => 'travis-core') }
  let(:build)   { create(:build, :repository => repo, :state => :finished, :number => 1) }
  let!(:event)  { create(:event, :event => 'build:finished', :repository => repo, :source => build) }
  let(:service) { described_class.new(stub('user'), params) }

  attr_reader :params

  describe 'run' do
    it 'finds events belonging to the given repository id' do
      @params = { :repository_id => repo.id }
      service.run.should == [event]
    end
  end

  describe 'updated_at' do
    it 'returns the latest updated_at time' do
      @params = { :repository_id => repo.id }
      Event.delete_all
      create(:event, :repository => repo, :updated_at => Time.now - 1.hour)
      create(:event, :repository => repo, :updated_at => Time.now)
      service.updated_at.to_s.should == Time.now.to_s
    end
  end
end

