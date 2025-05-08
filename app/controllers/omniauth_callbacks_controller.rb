class OmniauthCallbacksController < ApplicationController
  before_action :check_auth_flow_expiration, only: [ :callback ]

  def callback
    # 認証情報の取得
    auth = request.env["omniauth.auth"]
    provider = auth.provider

    # 既存の認証情報を検索
    authentication = Authentication.find_by(provider: provider, uid: auth.uid)

    # 認証フローの初期化（初回のみ）
    session[:auth_flow] ||= {
      step: 1,
      completed: [],
      started_at: Time.current
    }

    # 現在の認証プロバイダーを処理
    process_authentication(authentication, auth)

    # 認証プロバイダーを完了済みとしてマーク
    mark_auth_step_completed(provider)

    # 次のステップへリダイレクト
    redirect_to_next_auth_step
  end

  def failure
    # 認証失敗時のエラーメッセージ
    error_message = params[:message] || "認証に失敗しました"

    # 認証フローを継続するか中断するかの判断
    if session[:auth_flow] && session[:auth_flow][:step] > 1
      # 既に一部の認証が完了している場合は、一旦ダッシュボードへ
      redirect_to rankings_index_path, alert: "#{params[:provider]&.capitalize || '認証プロバイダー'}での認証に失敗しました: #{error_message}"
    else
      # まだ何も認証が完了していない場合はログイン画面へ
      reset_auth_flow
      redirect_to login_path, alert: "認証に失敗しました: #{error_message}"
    end
  end

  private

  def check_auth_flow_expiration
    if auth_flow_expired?
      handle_expired_auth_flow
    end
  end

  def process_authentication(authentication, auth)
    if current_user
      # ユーザーが既にログイン済み - アカウント連携のケース
      handle_logged_in_user(authentication, auth)
    else
      # ユーザーがログインしていない - ログインまたは新規登録のケース
      handle_non_logged_in_user(authentication, auth)
    end
  end

  def handle_logged_in_user(authentication, auth)
    if authentication
      # 既存の認証情報がある場合
      if authentication.user == current_user
        # 自分自身のアカウントを更新
        update_authentication(authentication, auth)
        flash[:notice] = "#{provider_name(auth)}の接続情報を更新しました"
      else
        # 他のユーザーのアカウントとの衝突
        flash[:alert] = "この#{provider_name(auth)}アカウントは既に他のユーザーに連携されています"
        # この認証ステップはスキップして次へ進む
        advance_auth_flow
      end
    else
      # 新規の認証情報を作成
      begin
        create_authentication(current_user, auth)
        flash[:notice] = "#{provider_name(auth)}のアカウントを接続しました"
      rescue => e
        Rails.logger.error "認証情報の作成中にエラーが発生しました: #{e.message}"
        flash[:alert] = "#{provider_name(auth)}アカウントの接続に失敗しました"

        # この認証ステップはスキップして次へ進む
        advance_auth_flow
      end
    end
  end

  def handle_non_logged_in_user(authentication, auth)
    if authentication
      # 既存の認証情報でログイン
      log_in_with_authentication(authentication, auth)
      flash[:notice] = "#{provider_name(auth)}でログインしました"
    else
      # 新規ユーザー登録とログイン
      begin
        user = register_and_login_user(auth)
        flash[:notice] = "#{provider_name(auth)}でアカウントを作成しました"
      rescue => e
        Rails.logger.error "新規ユーザー登録中にエラーが発生しました: #{e.message}"
        flash[:alert] = "アカウント作成中にエラーが発生しました"
        redirect_to login_path
      end
    end
  end

  def log_in_with_authentication(authentication, auth)
    # ユーザーをログインさせる
    session[:user_id] = authentication.user_id

    # 認証情報を更新
    update_authentication(authentication, auth)

    # 認証フローのユーザーIDを設定
    session[:auth_flow][:user_id] = authentication.user_id if session[:auth_flow]
  end

  def register_and_login_user(auth)
    user = nil

    ActiveRecord::Base.transaction do
      # トランザクション内でユーザー作成と認証情報作成を行う
      user = create_user_from_auth(auth)
      authentication = create_authentication(user, auth)

      # ユーザーをログインさせる
      session[:user_id] = user.id

      # 認証フローのユーザーIDを設定
      session[:auth_flow][:user_id] = user.id if session[:auth_flow]
    end

    user
  end

  def redirect_to_next_auth_step
    # 認証フローの状態を取得
    auth_flow = session[:auth_flow]
    current_step = auth_flow[:step]
    completed = auth_flow[:completed]

    # 認証の順序と次のステップを決定
    case current_step
    when 1
      # GitHub認証のステップ
      if completed.include?("github")
        # GitHubが完了したらTwitterへ
        auth_flow[:step] = 2
        redirect_to auth_flow_twitter_path
      else
        # まだGitHubが完了していなければGitHubへ
        redirect_to auth_flow_github_path
      end
    when 2
      # Twitter認証のステップ
      if completed.include?("twitter2")
        # Twitterが完了したらGoogleへ
        auth_flow[:step] = 3
        redirect_to auth_flow_google_path
      else
        # まだTwitterが完了していなければTwitterへ
        redirect_to auth_flow_twitter_path
      end
    when 3
      # Google認証のステップ
      if completed.include?("google_oauth2")
        # 全ての認証が完了
        auth_flow[:step] = 4

        # 認証完了後の処理
        redirect_to auth_flow_complete_path
      else
        # まだGoogleが完了していなければGoogleへ
        redirect_to auth_flow_google_path
      end
    else
      # 想定外のステップの場合はダッシュボードへ
      redirect_to rankings_index_path
    end
  end

  def finalize_auth_flow
    # 完了したプロバイダーを取得
    completed_providers = session[:auth_flow][:completed].uniq

    # 認証フローをリセット
    reset_auth_flow

    # 認証結果に応じたメッセージを設定
    if completed_providers.size >= 3
      flash[:notice] = "すべての認証が完了しました！"
    elsif completed_providers.any?
      flash[:notice] = "#{completed_providers.map(&:capitalize).join(', ')}の認証が完了しました。"
    end

    # ダッシュボードへリダイレクト
    redirect_to rankings_index_path
  end

  def reset_auth_flow
    session[:auth_flow] = nil
  end

  def mark_auth_step_completed(provider)
    session[:auth_flow][:completed] ||= []
    session[:auth_flow][:completed] << provider unless session[:auth_flow][:completed].include?(provider)
  end

  def advance_auth_flow
    session[:auth_flow][:step] = session[:auth_flow][:step] + 1
  end

  # 以下は既存のヘルパーメソッド
  def create_user_from_auth(auth)
    name = auth.info.name || auth.info.nickname || "ユーザー#{Time.now.to_i}"
    email = auth.info.email || "#{auth.uid}@#{auth.provider}.example.com"

    User.create!(
      name: name,
      email: email
    )
  end

  def create_authentication(user, auth)
    user.authentications.create!(
      provider: auth.provider,
      uid: auth.uid,
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil,
      info: auth.to_hash
    )
  end

  def update_authentication(authentication, auth)
    authentication.update!(
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil,
      info: auth.to_hash
    )
  end

  def provider_name(auth)
    auth.provider.capitalize
  end
end
