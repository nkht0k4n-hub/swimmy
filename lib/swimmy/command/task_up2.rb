require 'open3'
require 'json'
require 'date'
require 'time'

module Swimmy

  module Command

    class TaskUp < Swimmy::Command::Base
            command "task_up" do |client, data, match|
              begin
               user = client.web_client.users_info(user: data.user).user
               user_name = user.profile.display_name
               github_name = NameResolver.new(spreadsheet).name_slack_to_github(user_name)
               #if github_name.nil?
               # client.say(channel: data.channel, text: "ユーザ #{user_name}のGitHubアカウントが見つかりませんでした。")
               # next
               #else
               # client.say(channel: data.channel, text: "ユーザ #{user_name}のGitHubアカウントは #{github_name} です。")
               #end
               client.say(channel: data.channel, text: "タスクの締め切りをグーグルカレンダに登録します...")
               target_dir="/home/nakahata/git/rask_cli"
               command = "cargo run -- rask #{github_name}"
               RASK_URL = ENV["RASK_URL"]
               stdout,stderr,status= Open3.capture3(command,chdir: target_dir)
               if status.success?
                  msg=stdout.empty? ? "task_upの実行に成功しましたが、出力はありませんでした。" : stdout
                  
                  list = JSON.parse(msg)
                  today = Date.today
                  output_msg=""
                  last_day=Date.new(today.year, today.month, -1)


                  google_oauth ||= begin
                    Swimmy::Resource::GoogleOAuth.new('config/credentials.json', 'config/tokens.json')
                  rescue => e
                    msg = 'Google OAuthの認証に失敗しました．適切な認証情報が設定されているか確認してください．'
                    client.say(channel: data.channel, text: msg)
                    return
                  end
                  calendar_service = Swimmy::Service::GoogleCalendar.from_spreadsheet(google_oauth, spreadsheet, "nakahata")
                  for i in 1..last_day.day do
                    target_date_str = "#{today.year}-#{format('%02d', today.month)}-#{format('%02d', i)}"
                    for item in list do
                      if item["due_at"]&.include?(target_date_str) && item["assigner"]["name"]==github_name
                        task_name = item["content"]
                        start_time = Time.parse(item["due_at"]) - 3600 # 締め切りの1時間前を開始時間とする
                        start_time = start_time.strftime("%Y/%m/%d/%H:%M")
                        client.say(channel: data.channel, text: "タスクの開始時間: #{start_time}")
                        end_time = Time.parse(item["due_at"])
                        end_time = end_time.strftime("%Y/%m/%d/%H:%M")
                        event = Swimmy::Resource::CalendarEvent.new(task_name, start_time, end_time)
                        if check_event_exists?(event)
                          client.say(channel: data.channel, text: "タスク「#{task_name}」は既にカレンダーに登録されています。")
                        else
                            calendar_service.add_event(event)
                            client.say(channel: data.channel, text: "タスク「#{task_name}」をカレンダーに登録しました。")
                        end
                      end
                    end
                  end

                  
                else
                  error_msg = stderr.empty? ? "task_upの実行に失敗しましたが、エラーメッセージはありませんでした。" : stderr
                  client.say(channel: data.channel, text: error_msg)
                end

              rescue Errno::ENOENT
                client.say(channel: data.channel, text: "ディレクトリが見つかりません")
              rescue => e
                debug_msg = "エラー発生: #{e.message} (#{e.class})\n場所: #{e.backtrace.first}"
                client.say(channel: data.channel, text: debug_msg)
              end
            end

            def self.check_event_exists?(event)
              # ここでGoogle Calendar APIを呼び出して、同じ名前と時間のイベントが既に存在するか確認するロジックを実装
              # 例えば、calendar_service.get_events(event.start, event.end)のようなメソッドを呼び出して、返ってきたイベントの中に同じ名前のものがあるか確認する
              service =  Swimmy::Service::CalendarService.new
              sheet = spreadsheet.sheet("calendar", Swimmy::Resource::Calendar)
              calendars = sheet.fetch
              #calendarsは(カレンダー名，カレンダーid)の組
              events = service.get_events(calendars,event.name)
              puts "-------------------------------------------------------\n\n\n"
              p events
              puts "-------------------------------------------------------\n\n\n"
              if events.any? {|e| e && e.summary == event.name && e.start ==  event.start.iso8601}
                return true
              end
              false
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
