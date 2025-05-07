Rails.application.config.middleware.use OmniAuth::Builder do
    # GitHub
    provider :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], scope: "user,repo"

    # Twitter
    provider :twitter2, ENV["TWITTER_CLIENT_ID"], ENV["TWITTER_CLIENT_SECRET"],
      scope: "tweet.read users.read offline.access"
  end

  # 認証失敗時の処理
  OmniAuth.config.on_failure = Proc.new do |env|
    OmniAuth::FailureEndpoint.new(env).redirect_to_failure
  end

  OmniAuth.config.allowed_request_methods = [:post]
