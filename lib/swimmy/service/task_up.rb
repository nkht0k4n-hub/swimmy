require 'open3'
require 'json'
require 'date'
require 'time'

module Swimmy
  module Service
    class TaskUp
      class TaskUpError < StandardError; end

      RASK_CLI_DIR = "/home/nakahata/git/rask_cli/target/release".freeze

      def initialize(spreadsheet, target_dir: RASK_CLI_DIR)
        @spreadsheet = spreadsheet
        @target_dir = target_dir
      end

      def sync_rtask_to_google_calendar(slack_name)
        github_name = NameResolver.new(@spreadsheet).name_slack_to_github(slack_name)
        raise TaskUpError, "ユーザ #{slack_name} のGitHubアカウントが見つかりませんでした。" if github_name.nil?

        tasks = fetch_rtask_tasks(github_name)

        google_oauth = Resource::GoogleOAuth.new('config/credentials.json', 'config/tokens.json')
        calendar_service = Service::GoogleCalendar.from_spreadsheet(google_oauth, @spreadsheet, "GN")

        messages = []
        tasks.each do |task|
          next unless task.due_this_month?(Date.today)

          event = Resource::CalendarEvent.new(task.content, task.start_time_as_string, task.end_time_as_string)
          if event_registered?(event)
            messages << "タスク「#{task.content}」は既にカレンダーに登録されています。"
          else
            calendar_service.add_event(event)
            messages << "タスク「#{task.content}」をカレンダーに登録しました。"
          end
        end

        messages.empty? ? "同期対象のタスクはありませんでした。" : messages.join("\n")
      rescue Errno::ENOENT => e
        raise TaskUpError, "必要なファイルまたはディレクトリが見つかりませんでした: #{e.message}"
      end

      private

      def fetch_rtask_tasks(github_name)
        command = "./rask_cli get_tasks #{github_name} -j"
        stdout, stderr, status = Open3.capture3(command, chdir: @target_dir)

        unless status.success?
          error_msg = stderr.empty? ? "rtaskの実行に失敗しましたが、エラーメッセージはありませんでした。" : stderr
          raise TaskUpError, error_msg
        end

        msg = stdout.empty? ? "rtaskの実行に成功しましたが、出力はありませんでした。" : stdout
        list = parse_rtask_json(msg)
        list.map { |attrs| Resource::TaskUpTask.new(attrs) }
      end

      def parse_rtask_json(json_string)
        JSON.parse(json_string)
      rescue JSON::ParserError
        raise TaskUpError, "JSONのパースに失敗しました。出力内容を確認してください。"
      end

      def event_registered?(event)
        sheet = @spreadsheet.sheet("calendar", Resource::Calendar)
        calendars = sheet.fetch
        events = Service::CalendarService.new.get_events(calendars, event.name)
        events.any? do |existing|
          existing && existing.summary == event.name && existing.start.iso8601 == event.start.iso8601
        end
      end

      class NameResolver
        require "sheetq"

        def initialize(spreadsheet)
          @spreadsheet = spreadsheet
        end

        def name_slack_to_github(slack_name)
          members = @spreadsheet.sheet("members", Resource::Member).fetch
          member = members.find { |m| m.account == slack_name }
          member&.github
        end
      end
    end
  end
end
