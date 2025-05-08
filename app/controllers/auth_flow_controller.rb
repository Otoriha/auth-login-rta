class AuthFlowController < ApplicationController
    def start
      # 既存のフローがあれば初期化
      reset_auth_flow

      # 認証フローの初期化
      session[:auth_flow] = {
        step: 1,
        completed: [],
        started_at: Time.current
      }
      # 既にログイン済みの場合はユーザーIDを保存
      if current_user
        session[:auth_flow][:user_id] = current_user.id
      end

      # 最初のステップ（GitHub認証）へリダイレクト
      redirect_to "/auth/github"
    end

    private

    def reset_auth_flow
      session[:auth_flow] = nil
    end
end
