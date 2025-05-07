class SessionsController < ApplicationController
  def new
  end

  def create
    redirect_to dashboard_path if logged_in?
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "ログアウトしました"
  end
end
