module Swimmy

  module Command

    class RTaskToGC < Swimmy::Command::Base
      command "rtask_to_gc" do |client, data, match|
        begin
          user = client.web_client.users_info(user: data.user).user
          user_name = user.profile.display_name
          raise ArgumentError, "ユーザの表示名が見つかりませんでした。" if user_name.nil?

          result = Swimmy::Service::TaskUp.new(spreadsheet).sync_rtask_to_google_calendar(user_name)
          client.say(channel: data.channel, text: result)
        rescue Swimmy::Service::TaskUp::TaskUpError => e
          client.say(channel: data.channel, text: e.message)
        rescue Errno::ENOENT => e
          client.say(channel: data.channel, text: "必要なファイルまたはディレクトリが見つかりませんでした: #{e.message}")
        rescue => e
          debug_msg = "エラー発生: #{e.message} (#{e.class})\n場所: #{e.backtrace.first}"
          client.say(channel: data.channel, text: debug_msg)
        end
      end

      help do
        title "rtask_to_gc"
        desc "rtaskのタスクをGoogle Calendarに同期します。"
        long_desc "rtask_to_gc\nGitHub上のタスクをGoogle Calendarへ登録します。"
      end
    end

  end

end
