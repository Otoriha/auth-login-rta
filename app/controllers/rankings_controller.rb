class RankingsController < ApplicationController
  def index
    # 認証を完了したユーザーを所要時間でソート
    @rankings = User.where.not(auth_completed_at: nil)
                   .where.not(auth_duration: nil)
                   .order(auth_duration: :asc)
                   .limit(100)
    # 現在のユーザーのランキング位置を取得
    @current_user_rank = nil
    if current_user && current_user.auth_completed_at.present?
      @current_user_rank = @rankings.index { |user| user.id == current_user.id }&.+(1)
    end
  end

  def reset_record
    if current_user
      # 認証情報をリセット
      current_user.update(
        name: nil,
        auth_started_at: nil,
        auth_completed_at: nil,
        auth_duration: nil
      )
      # 認証情報（Authentication）を削除
      current_user.authentications.destroy_all
      # 認証フローのセッションをリセット
      session[:auth_flow] = nil
      # ユーザーセッションをリセット
      session[:user_id] = nil
      flash[:notice] = "記録をリセットしました。もう一度ログインRTAにチャレンジできます！"
    end
    redirect_to login_path
  end
end
