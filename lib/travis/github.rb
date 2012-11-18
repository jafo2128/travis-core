module Travis
  module Github
    autoload :Services, 'travis/github/services'

    class << self
      def authenticated(user, &block)
        fail "we don't have a github token for #{user.inspect}" if user.github_oauth_token.blank?
        GH.with(:token => user.github_oauth_token, &block)
      end
    end
  end
end
