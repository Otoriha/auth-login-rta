# app/controllers/auth_flow_controller.rb
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

    # 最初のステップ（GitHub認証）の画面へリダイレクト
    redirect_to auth_flow_github_path
  end

  def github
    # GitHub認証画面を表示
  end

  def twitter
    # Twitter認証画面を表示
    unless session[:auth_flow] && session[:auth_flow][:completed]&.include?("github")
      flash[:alert] = "GitHubでの認証が必要です"
      redirect_to auth_flow_github_path
    end
  end

  def google
    # Google認証画面を表示
    unless session[:auth_flow] && session[:auth_flow][:completed]&.include?("twitter2")
      flash[:alert] = "Twitterでの認証が必要です"
      redirect_to auth_flow_twitter_path
    end
  end

  def complete
    # 認証完了画面を表示
    providers = %w[github twitter2 google_oauth2]
    unless session[:auth_flow] && providers.all? { |p| session[:auth_flow][:completed]&.include?(p) }
      flash[:alert] = "すべての認証を完了してください"
      redirect_to auth_flow_github_path
    end
  end

  private

  def reset_auth_flow
    session[:auth_flow] = nil
  end
end
