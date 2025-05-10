class OmniauthCallbacksController < ApplicationController
  before_action :check_auth_flow_expiration, only: [ :callback ]

  def passthru
    render status: 404, plain: "Not found"
  end

  def callback
    auth = request.env["omniauth.auth"]
    provider = auth.provider

    authentication = Authentication.find_by(provider: provider, uid: auth.uid)

    session[:auth_flow] ||= {
      "step" => 1,
      "completed" => [],
      "started_at" => Time.current
    }

    process_authentication(authentication, auth)

    mark_auth_step_completed(provider)

    redirect_to_next_auth_step and return
  end

  def failure
    error_message = params[:message] || "認証に失敗しました"

    if session[:auth_flow] && session[:auth_flow]["step"] > 1
      redirect_to rankings_index_path, alert: "#{params[:provider]&.capitalize || '認証プロバイダー'}での認証に失敗しました: #{error_message}"
    else
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
      handle_logged_in_user(authentication, auth)
    else
      handle_non_logged_in_user(authentication, auth)
    end
    nil
  end

  def handle_logged_in_user(authentication, auth)
    if authentication
      if authentication.user == current_user
        update_authentication(authentication, auth)
        flash[:notice] = "#{provider_name(auth)}の接続情報を更新しました"
      else
        flash[:alert] = "この#{provider_name(auth)}アカウントは既に他のユーザーに連携されています"
        advance_auth_flow
      end
    else
      begin
        create_authentication(current_user, auth)
        flash[:notice] = "#{provider_name(auth)}のアカウントを接続しました"
      rescue => e
        flash[:alert] = "#{provider_name(auth)}アカウントの接続に失敗しました"
        advance_auth_flow
      end
    end
  end

  def handle_non_logged_in_user(authentication, auth)
    if authentication
      log_in_with_authentication(authentication, auth)
      flash[:notice] = "#{provider_name(auth)}でログインしました"
    else
      begin
        user = register_and_login_user(auth)
        flash[:notice] = "#{provider_name(auth)}でアカウントを作成しました"
      rescue => e
        flash[:alert] = "アカウント作成中にエラーが発生しました"
        redirect_to login_path
      end
    end
  end

  def log_in_with_authentication(authentication, auth)
    session[:user_id] = authentication.user_id
    update_authentication(authentication, auth)
    session[:auth_flow]["user_id"] = authentication.user_id if session[:auth_flow]
  end

  def register_and_login_user(auth)
    user = nil

    ActiveRecord::Base.transaction do
      user = create_user_from_auth(auth)
      authentication = create_authentication(user, auth)
      session[:user_id] = user.id
      session[:auth_flow]["user_id"] = user.id if session[:auth_flow]
    end

    user
  end

  def redirect_to_next_auth_step
    auth_flow = session[:auth_flow]
    current_step = auth_flow["step"]
    completed = auth_flow["completed"]

    case current_step
    when 1
      if completed.include?("github")
        auth_flow["step"] = 2
        redirect_to auth_flow_twitter_path and return
      else
        redirect_to auth_flow_github_path and return
      end
    when 2
      if completed.include?("twitter2")
        auth_flow["step"] = 3
        redirect_to auth_flow_google_path and return
      else
        redirect_to auth_flow_twitter_path and return
      end
    when 3
      if completed.include?("google_oauth2")
        auth_flow["step"] = 4
        redirect_to auth_flow_complete_path and return
      else
        redirect_to auth_flow_google_path and return
      end
    else
      reset_auth_flow
      redirect_to login_path, alert: "認証フローが不正な状態です。最初からやり直してください。" and return
    end
  end

  def finalize_auth_flow
    completed_providers = session[:auth_flow]["completed"].uniq
    reset_auth_flow

    if completed_providers.size >= 3
      flash[:notice] = "すべての認証が完了しました！"
    elsif completed_providers.any?
      flash[:notice] = "#{completed_providers.map(&:capitalize).join(', ')}の認証が完了しました。"
    end

    redirect_to rankings_index_path
  end

  def reset_auth_flow
    session[:auth_flow] = nil
  end

  def mark_auth_step_completed(provider)
    session[:auth_flow]["completed"] ||= []
    session[:auth_flow]["completed"] << provider unless session[:auth_flow]["completed"].include?(provider)
  end

  def advance_auth_flow
    session[:auth_flow]["step"] = session[:auth_flow]["step"] + 1
  end

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
