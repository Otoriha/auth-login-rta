# app/controllers/auth_flow_controller.rb
class AuthFlowController < ApplicationController
  def start
    reset_auth_flow

    nickname = params[:name]

    if current_user
      current_user.update(name: nickname) if nickname.present?
      user_id = current_user.id
    else
      user = User.create(name: nickname) if nickname.present?
      user_id = user&.id
    end

    if user_id
      user_to_update = User.find_by(id: user_id)
      user_to_update&.update(auth_started_at: Time.current, auth_completed_at: nil, auth_duration: nil)
    end

    session[:auth_flow] = {
      step: 1,
      completed: [],
      started_at: Time.current,
      user_id: user_id,
      nickname: nickname
    }

    redirect_to auth_flow_github_path
  end

  def github
    is_github_completed = auth_flow_completed_for?("github")

    if is_github_completed
      redirect_to auth_flow_twitter_path
    end
  end

  def twitter
    is_github_completed = auth_flow_completed_for?("github")

    unless is_github_completed
      flash[:alert] = "GitHubでの認証が必要です"
      redirect_to auth_flow_github_path and return
    end

    is_twitter_completed = auth_flow_completed_for?("twitter2")

    if is_twitter_completed
      redirect_to auth_flow_google_path
    end
  end

  def google
    is_twitter_completed = auth_flow_completed_for?("twitter2")

    unless is_twitter_completed
      flash[:alert] = "Twitterでの認証が必要です"
      redirect_to auth_flow_twitter_path and return
    end

    is_google_completed = auth_flow_completed_for?("google_oauth2")

    if is_google_completed
      redirect_to auth_flow_complete_path
    end
  end

  def complete
    raw_auth_flow_session = session[:auth_flow]
    auth_flow_session = nil
    if raw_auth_flow_session.is_a?(Hash)
      auth_flow_session = raw_auth_flow_session.with_indifferent_access
    end

    providers = %w[github twitter2 google_oauth2]
    auth_flow_session_exists = auth_flow_session.present?
    completed_steps_array = auth_flow_session[:completed] if auth_flow_session_exists

    all_providers_completed = if auth_flow_session_exists && completed_steps_array.is_a?(Array)
                                providers.all? { |p| completed_steps_array.include?(p) }
    else
                                false
    end

    unless auth_flow_session_exists && all_providers_completed
      flash[:alert] = "すべての認証を完了できませんでした。お手数ですが、最初からやり直してください。"
      reset_auth_flow
      redirect_to auth_flow_start_path and return
    end

    user_id = auth_flow_session[:user_id] if auth_flow_session.present?
    if user_id
      user = User.find_by(id: user_id)
      if user
        completed_at = Time.current
        started_at_from_session = auth_flow_session[:started_at] if auth_flow_session.present?
        final_started_at = user.auth_started_at || started_at_from_session

        duration = nil
        if final_started_at
          final_started_at = Time.parse(final_started_at) if final_started_at.is_a?(String)
          completed_at = Time.parse(completed_at) if completed_at.is_a?(String)

          if final_started_at.is_a?(Time) && completed_at.is_a?(Time)
            duration = ((completed_at - final_started_at) * 1000).to_i
          end
        end

        user.update(
          auth_completed_at: completed_at,
          auth_duration: duration
        )
      end
    end

    reset_auth_flow
    flash[:notice] = "すべての認証が完了しました！"
    redirect_to rankings_index_path and return
  end

  private

  def reset_auth_flow
    session[:auth_flow] = nil
  end

  def auth_flow_completed_for?(provider_to_check)
    raw_auth_flow_session = session[:auth_flow]

    if raw_auth_flow_session.nil? || !raw_auth_flow_session.is_a?(Hash)
      return false
    end

    auth_flow_session = raw_auth_flow_session.with_indifferent_access
    completed_array = auth_flow_session[:completed]

    if completed_array.nil? || !completed_array.is_a?(Array)
      return false
    end

    completed_array.include?(provider_to_check)
  end
end
