module AuthFlowHelper
    def auth_flow_progress_bar
      return nil unless session[:auth_flow]

      steps = [ "GitHub", "Twitter", "Google" ]
      current_step = session[:auth_flow][:step]
      completed = session[:auth_flow][:completed] || []

      content_tag :div, class: "auth-flow-progress mb-6" do
        content_tag :div, class: "flex items-center justify-between" do
          steps.each_with_index.map do |provider, index|
            step_num = index + 1

            # ステップの状態を決定
            if completed.include?(provider.downcase)
              status = "completed"
            elsif step_num == current_step
              status = "current"
            else
              status = "pending"
            end

            # ステップ表示用のHTMLを生成
            step_html = content_tag :div, class: "flex flex-col items-center" do
              concat content_tag(:div, step_num, class: "w-10 h-10 rounded-full flex items-center justify-center #{status_color(status)}")
              concat content_tag(:span, provider, class: "mt-2 text-sm")
            end

            # 最後のステップ以外は接続線を表示
            if index < steps.length - 1
              step_html + content_tag(:div, "", class: "flex-1 h-1 mx-2 #{line_color(status, completed, step_num)}")
            else
              step_html
            end
          end.join.html_safe
        end
      end
    end

    private

    def status_color(status)
      case status
      when "completed"
        "bg-green-500 text-white"
      when "current"
        "bg-blue-500 text-white"
      else
        "bg-gray-300 text-gray-700"
      end
    end

    def line_color(status, completed, step_num)
      if completed.include?(step_num.to_s)
        "bg-green-500"
      else
        "bg-gray-300"
      end
    end
end
