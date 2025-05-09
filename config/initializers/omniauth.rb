Rails.application.config.middleware.use OmniAuth::Builder do
    # GitHub
    provider :github, ENV["GITHUB_KEY"], ENV["GITHUB_SECRET"], scope: "user,repo"

    # Twitter
    provider :twitter2, ENV["TWITTER_CLIENT_ID"], ENV["TWITTER_CLIENT_SECRET"],
      scope: "tweet.read users.read offline.access"

    # Google
    provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], {
      scope: "email, profile" # 要求するスコープ
    }
  end

  # 認証失敗時の処理
  OmniAuth.config.on_failure = Proc.new do |env|
    OmniAuth::FailureEndpoint.new(env).redirect_to_failure
  end

  OmniAuth.config.allowed_request_methods = [ :post, :get ]
