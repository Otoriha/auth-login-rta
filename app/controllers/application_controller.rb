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
