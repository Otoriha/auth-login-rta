class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  def current_auth_flow
    session[:auth_flow] || {}
  end

  def auth_flow_step
    current_auth_flow[:step] || 0
  end

  def auth_flow_completed
    current_auth_flow[:completed] || []
  end

  def mark_auth_step_completed(provider)
    session[:auth_flow] ||= { step: 1, completed: [] }
    session[:auth_flow][:completed] ||= []
    session[:auth_flow][:completed] << provider unless session[:auth_flow][:completed].include?(provider)
  end

  def advance_auth_flow
    session[:auth_flow] ||= { step: 1, completed: [] }
    session[:auth_flow][:step] = session[:auth_flow][:step] + 1
  end

  def auth_flow_expired?
    # 認証フローが存在しない、または開始から30分以上経過している場合は期限切れ
    !session[:auth_flow] ||
      (session[:auth_flow][:started_at] &&
       Time.parse(session[:auth_flow][:started_at].to_s) < 30.minutes.ago)
  end

  def handle_expired_auth_flow
    flash[:alert] = "認証セッションの有効期限が切れました。再度お試しください。"
    reset_auth_flow
    redirect_to login_path
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      flash[:alert] = "ログインしてください"
      redirect_to login_path
    end
  end
end
