require 'open3'
require 'json'
require 'date'
require 'time'

module Swimmy

  module Command

    class RTaskToGC < Swimmy::Command::Base
            command "rtask_to_gc" do |client, data, match|
              begin
               user = client.web_client.users_info(user: data.user).user
               user_name = user.profile.display_name
               if user_name.nil?
                error_msg="ユーザの表示名が見つかりませんでした。"
                raise
               end
               github_name = NameResolver.new(spreadsheet).name_slack_to_github(user_name)
               if github_name.nil?
                error_msg="ユーザ #{user_name}のGitHubアカウントが見つかりませんでした。"
                raise
               end
               #else
               # client.say(channel: data.channel, text: "ユーザ #{user_name}のGitHubアカウントは #{github_name} です。")
               #end
               
               target_dir="/home/nakahata/git/rask_cli/target/release"
               command = "./rask_cli get_tasks #{github_name} -j"
               RASK_URL = ENV["RASK_URL"]
               stdout,stderr,status= Open3.capture3(command,chdir: target_dir)
               if status.success?
                  msg=stdout.empty? ? "rtask_to_gcの実行に成功しましたが、出力はありませんでした。" : stdout
                  
                  begin
                    list = JSON.parse(msg)
                  rescue JSON::ParserError=>e
                    error_msg="JSONのパースに失敗しました。出力内容を確認してください。"
                    raise
                  end
                  # p list
                  today = Date.today
                  output_msg=""
                  last_day=Date.new(today.year, today.month, -1)


                  google_oauth ||= begin
                    Swimmy::Resource::GoogleOAuth.new('config/credentials.json', 'config/tokens.json')
                  rescue => e
                    error_msg = 'Google OAuthの認証に失敗しました．適切な認証情報が設定されているか確認してください．'
                    raise
                  end
                  begin
                    calendar_service = Swimmy::Service::GoogleCalendar.from_spreadsheet(google_oauth, spreadsheet, "GN")
                  rescue => e
                    error_msg = 'Google Calendarのサービスの初期化に失敗しました．スプレッドシートの設定を確認してください．'
                    raise
                  end

                  range = 1..last_day.day

                  range.each do |i|
                    target_date_str = "#{today.year}-#{format('%02d', today.month)}-#{format('%02d', i)}"
                    list.each do |item|
                      if item["due_at"]&.include?(target_date_str)
                        task_name = item["content"]
                        start_time = Time.parse(item["due_at"]) - 3600 # 締め切りの1時間前を開始時間とする
                        start_time = start_time.strftime("%Y/%m/%d/%H:%M")
                        end_time = Time.parse(item["due_at"])
                        end_time = end_time.strftime("%Y/%m/%d/%H:%M")
                        client.say(channel: data.channel, text: "タスクの締切時間: #{end_time}")
                        #client.say(channel: data.channel, text: "タスクの締め切りをグーグルカレンダに登録します...")
                        event = Swimmy::Resource::CalendarEvent.new(task_name, start_time, end_time)
                        # puts "-------------------------------------------------------\n\n\n"
                        # p event
                        # puts "-------------------------------------------------------\n\n\n"
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
                  error_msg = stderr.empty? ? "rtask_to_gc の実行に失敗しましたが、エラーメッセージはありませんでした。" : stderr
                  raise
                end

              rescue Errno::ENOENT
                error_msg_d="パス#{target_dir}が見つかりませんでした．"
                client.say(channel: data.channel, text: error_msg_d)  
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
                # puts "-------------------------------------------------------\n\n\n"
                # p events
                # puts "-------------------------------------------------------\n\n\n"
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
