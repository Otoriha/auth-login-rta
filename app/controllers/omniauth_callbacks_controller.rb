class OmniauthCallbacksController < ApplicationController
    def callback
      auth = request.env["omniauth.auth"]
      authentication = Authentication.find_by(provider: auth.provider, uid: auth.uid)

      # この認証プロセスを処理するメソッドを呼び出す
      process_authentication(authentication, auth)
    end

    def failure
      redirect_to login_path, alert: "認証に失敗しました: #{params[:message]}"
    end

    private

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
          redirect_to dashboard_path, notice: "#{provider_name(auth)}の接続情報を更新しました。"
        else
          # 他のユーザーのアカウントとの衝突
          redirect_to dashboard_path, alert: "この#{provider_name(auth)}アカウントは既に他のユーザーに連携されています。"
        end
      else
        # 新規の認証情報
        begin
          create_authentication(current_user, auth)
          redirect_to dashboard_path, notice: "#{provider_name(auth)}のアカウントを接続しました。"
        rescue => e
          Rails.logger.error "認証情報の作成中にエラーが発生しました: #{e.message}"
          redirect_to dashboard_path, alert: "#{provider_name(auth)}アカウントの接続に失敗しました。"
        end
      end
    end

    def handle_non_logged_in_user(authentication, auth)
      if authentication
        # 既存の認証情報でログイン
        log_in_with_authentication(authentication, auth)
      else
        # 新規ユーザー登録とログイン
        register_and_login_user(auth)
      end
    end

    def log_in_with_authentication(authentication, auth)
      session[:user_id] = authentication.user_id
      update_authentication(authentication, auth)
      redirect_to dashboard_path, notice: "#{provider_name(auth)}でログインしました。"
    end

    def register_and_login_user(auth)
      ActiveRecord::Base.transaction do
        # トランザクション内でユーザー作成と認証情報作成を行う
        user = create_user_from_auth(auth)
        authentication = create_authentication(user, auth)
        session[:user_id] = user.id
      end
      redirect_to dashboard_path, notice: "#{provider_name(auth)}でアカウントを作成しました。"
    rescue => e
      Rails.logger.error "新規ユーザー登録中にエラーが発生しました: #{e.message}"
      redirect_to login_path, alert: "ログイン処理中にエラーが発生しました。"
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
