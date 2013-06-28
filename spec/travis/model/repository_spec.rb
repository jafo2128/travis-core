require 'spec_helper'

describe Repository do
  include Support::ActiveRecord

  describe '#last_completed_build' do
    let(:repo) {  create(:repository, name: 'foobarbaz', builds: [build1, build2]) }
    let(:build1) { create(:build, finished_at: 1.hour.ago, state: :passed) }
    let(:build2) { create(:build, finished_at: Time.now, state: :failed) }

    before do
      build1.update_attributes(branch: 'master')
      build2.update_attributes(branch: 'development')
    end

    it 'returns last completed build' do
      repo.last_completed_build.should == build2
    end

    it 'returns last completed build for a branch' do
      repo.last_completed_build('master').should == build1
    end
  end

  describe '#regenerate_key!' do
    it 'regenerates key' do
      repo = create(:repository)

      expect { repo.regenerate_key! }.to change { repo.key.private_key }
    end
  end

  describe 'validates' do
    it 'uniqueness of :owner_name/:name' do
      existing = create(:repository)
      repo = Repository.new(existing.attributes.except('last_build_status'))
      repo.should_not be_valid
      repo.errors['name'].should == ['has already been taken']
    end
  end

  describe 'associations' do
    describe 'owner' do
      let(:user) { create(:user) }
      let(:org)  { create(:org)  }

      it 'can be a user' do
        repo = create(:repository, owner: user)
        repo.reload.owner.should == user
      end

      it 'can be an organization' do
        repo = create(:repository, owner: org)
        repo.reload.owner.should == org
      end
    end
  end

  describe 'class methods' do
    describe 'find_by' do
      let(:minimal) { create(:repository) }

      it "should find a repository by it's id" do
        Repository.find_by(id: minimal.id).id.should == minimal.id
      end

      it "should find a repository by it's name and owner_name" do
        repo = Repository.find_by(name: minimal.name, owner_name: minimal.owner_name)
        repo.owner_name.should == minimal.owner_name
        repo.name.should == minimal.name
      end

      it "returns nil when a repository couldn't be found using params" do
        Repository.find_by(name: 'emptiness').should be_nil
      end
    end

    describe 'timeline' do
      it 'sorts the most repository with the most recent build to the top' do
        one   = create(:repository, name: 'one',   last_build_started_at: '2011-11-11')
        two   = create(:repository, name: 'two',   last_build_started_at: '2011-11-12')

        repositories = Repository.timeline.all
        repositories.first.id.should == two.id
        repositories.last.id.should  == one.id
      end
    end


    describe 'with_builds' do
      it 'gets only projects with existing builds' do
        one   = create(:repository, name: 'one',   last_build_started_at: '2011-11-11', last_build_id: nil)
        two   = create(:repository, name: 'two',   last_build_started_at: '2011-11-12', last_build_id: 101)
        three = create(:repository, name: 'three', last_build_started_at: nil, last_build_id: 100)

        repositories = Repository.with_builds.all
        repositories.map(&:id).sort.should == [two, three].map(&:id).sort
      end
    end

    describe 'active' do
      let(:active)   { create(:repository, active: true) }
      let(:inactive) { create(:repository, active: false) }

      it 'contains active repositories' do
        Repository.active.should include(active)
      end

      it 'does not include inactive repositories' do
        Repository.active.should_not include(inactive)
      end
    end

    describe 'search' do
      before(:each) do
        create(:repository, name: 'repo 1', last_build_started_at: '2011-11-11')
        create(:repository, name: 'repo 2', last_build_started_at: '2011-11-12')
      end

      it 'performs searches case-insensitive' do
        Repository.search('rEpO').to_a.count.should == 2
      end

      it 'performs searches with / entered' do
        Repository.search('fuchs/').to_a.count.should == 2
      end

      it 'performs searches with \ entered' do
        Repository.search('fuchs\\').to_a.count.should == 2
      end
    end

    describe 'by_member' do
      let(:user) { create(:user) }
      let(:org)  { create(:org) }
      let(:user_repo) { create(:repository, owner: user)}
      let(:org_repo)  { create(:repository, owner: org, name: 'globalize')}

      before do
        Permission.create!(user: user, repository: user_repo, pull: true, push: true)
        Permission.create!(user: user, repository: org_repo, pull: true)
      end

      it 'returns all repositories a user has rights to' do
        Repository.by_member('svenfuchs').should have(2).items
      end
    end

    describe 'counts_by_owner_names' do
      let!(:repositories) do
        create(:repository, owner_name: 'svenfuchs', name: 'minimal')
        create(:repository, owner_name: 'travis-ci', name: 'travis-ci')
      end

      it 'returns repository counts per owner_name for the given owner_names' do
        counts = Repository.counts_by_owner_names(%w(svenfuchs travis-ci))
        counts.should == { 'svenfuchs' => 1, 'travis-ci' => 1 }
      end
    end
  end

  describe 'source_url' do
    let(:repo) { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }

    it 'returns the public git source url for a public repository' do
      repo.private = false
      repo.source_url.should == 'git://github.com/travis-ci/travis-ci.git'
    end

    it 'returns the private git source url for a private repository' do
      repo.private = true
      repo.source_url.should == 'git@github.com:travis-ci/travis-ci.git'
    end
  end

  it "last_build returns the most recent build" do
    repo = create(:repository)
    attributes = { repository: repo, state: 'finished' }
    create(:build, attributes)
    create(:build, attributes)
    build = create(:build, attributes)

    repo.last_build.id.should == build.id
  end

  describe "keys" do
    let(:repo) { create(:repository) }

    it "should return the public key" do
      repo.public_key.should == repo.key.public_key
    end

    it "should create a new key when the repository is created" do
      repo = Repository.create!(owner_name: 'travis-ci', name: 'travis-ci')
      repo.key.should_not be_nil
    end
  end

  describe 'branches' do
    let(:repo) { create(:repository) }

    it 'returns branches for the given repository' do
      %w(master production).each do |branch|
        2.times { create(:build, repository: repo, commit: create(:commit, branch: branch)) }
      end
      repo.branches.sort.should == %w(master production)
    end

    it 'is empty for empty repository' do
      repo.branches.should eql []
    end
  end

  describe 'last_finished_builds_by_branches' do
    let(:repo) { create(:repository) }

    it 'retrieves last builds on all branches' do
      Build.delete_all
      old = create(:build, repository: repo, finished_at: 1.hour.ago,      state: 'finished', commit: create(:commit, branch: 'one'))
      one = create(:build, repository: repo, finished_at: 1.hour.from_now, state: 'finished', commit: create(:commit, branch: 'one'))
      two = create(:build, repository: repo, finished_at: 1.hour.from_now, state: 'finished', commit: create(:commit, branch: 'two'))

      builds = repo.last_finished_builds_by_branches
      builds.size.should == 2
      builds.should include(one)
      builds.should include(two)
      builds.should_not include(old)
    end
  end
end
