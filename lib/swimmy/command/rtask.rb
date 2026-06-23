require "swimmy/service/rtask"

module Swimmy

  module Command

    class RTask < Swimmy::Command::Base
      command "rtask" do |client, data, match|
        begin
          user = client.web_client.users_info(user: data.user).user
          user_name = user.profile.display_name
          raise ArgumentError, "ユーザの表示名が見つかりませんでした．" if user_name.nil?

          result = Swimmy::Service::RTask.new(spreadsheet,target_dir:ENV['RASK_CLI_PASS'],rask_url:ENV['RASK_URL']).list_tasks(user_name)
          client.say(channel: data.channel, text: result)
        rescue Swimmy::Service::RTask::RTaskError => e
          client.say(channel: data.channel, text: e.message)
   
        rescue Errno::ENOENT => e
          client.say(channel: data.channel, text: "必要なファイルまたはディレクトリが見つかりませんでした: #{e.message}")
        rescue => e
          puts e.full_message

          raise
        end
      end

      help do
        title "rtask"
        desc "rtaskのタスクと期限を表示します．"
        long_desc "rtask\nGitHubのタスクを月ごとに一覧表示します．"
      end
    end

  end

end
