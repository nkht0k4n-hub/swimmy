require 'open3'
require 'json'
require 'date'

module Swimmy

  module Command

    class RTask < Swimmy::Command::Base
            command "rtask" do |client, data, match|
              begin
               user = client.web_client.users_info(user: data.user).user
               user_name = user.profile.display_name
               
               github_name = NameResolver.new(spreadsheet).name_slack_to_github(user_name)
               #github_name = NameResolver.new(spreadsheet).name_slack_to_github("atrantica")
               if github_name.nil?
                error_msg="ユーザ #{user_name}のGitHubアカウントが見つかりませんでした．"
                #client.say(channel: data.channel, text: "ユーザ #{user_name}のGitHubアカウントが見つかりませんでした。")
               end
               # next
               #else
               #client.say(channel: data.channel, text: "ユーザ #{user_name}のGitHubアカウントは #{github_name} です。")
               #end
               client.say(channel: data.channel, text: "タスクの締め切りを表示します...")
               target_dir="/home/nakahata/git/rask_cli"
               command = "cargo run -- rtask #{github_name}"
               RASK_URL = ENV["RASK_URL"]
               stdout,stderr,status= Open3.capture3(command,chdir: target_dir)
               if status.success?
                  msg=stdout.empty? ? "taskの実行に成功しましたが、出力はありませんでした。" : stdout
                  client.say(channel: data.channel, text:"body=#{msg}")
                  list = JSON.parse(msg)
                  today = Date.today
                  output_msg=""
                  last_day=Date.new(today.year, today.month, -1)
                  for i in 1..last_day.day do
                    daily_tasks=[]
                    task_id=[]
                    target_date_str = "#{today.year}-#{format('%02d', today.month)}-#{format('%02d', i)}"
                    for item in list do
                      if item["due_at"]&.include?(target_date_str)
                        daily_tasks << item["content"]
                        task_id << item["id"]
                      end
                    end
                    count=0
                    if daily_tasks.any?
                      output_msg += "#{today.month}月#{i}日:\n"
                      daily_tasks.each do |task|
                        output_msg += "  - #{task}:"
                        output_msg += "    #{RASK_URL}/tasks/#{task_id[count]}\n"
                        count += 1
                      end
                    end
                  end
                  client.say(channel: data.channel, text: output_msg) if output_msg != ""

                  
                else
                  error_msg = stderr.empty? ? "taskの実行に失敗しましたが、エラーメッセージはありませんでした。" : stderr
                  client.say(channel: data.channel, text: error_msg)
                end

              rescue Errno::ENOENT
                error_msg_d="ディレクトリ#{target_dir}が見つかりませんでした．"
                client.say(channel: data.channel, text: error_msg_d)
              rescue => e
                client.say(channel: data.channel, text: error_msg)
                # debug_msg = "エラー発生: #{e.message} (#{e.class})\n場所: #{e.backtrace.first}"
                # client.say(channel: data.channel, text: debug_msg)
              end
            end
    end

    class NameResolver
      require "sheetq"
      attr_reader :spreadsheet
      def initialize(spreadsheet)
          @spreadsheet = spreadsheet
      end

      def name_slack_to_github(slack_name)
          members = spreadsheet.sheet("members", Swimmy::Resource::Member).fetch
          member = members.find {|m| m.account== slack_name}
          member&.github
      end
        # ここでSlackのユーザ名をGitHubのユーザ名に変換するロジックを実
    end
  end

end
