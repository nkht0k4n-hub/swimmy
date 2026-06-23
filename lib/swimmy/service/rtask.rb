require 'open3'
require 'json'
require 'date'
require 'time'
require 'swimmy/resource'

module Swimmy
  module Service
    class RTask
      class RTaskError < StandardError; end

      def initialize(spreadsheet, target_dir: RASK_CLI_DIR,rask_url:RASK_URL)
        @spreadsheet = spreadsheet
        @target_dir = target_dir
        @rask_url=rask_url
      end

      def list_tasks(slack_name)
        github_name = NameResolver.new(@spreadsheet).name_slack_to_github(slack_name)
        raise RTaskError, "ユーザ #{slack_name}の GitHub アカウントが見つかりませんでした．" if github_name.nil?

        tasks = fetch_rask_tasks(github_name)
        output_tasks(tasks)
      rescue Errno::ENOENT => e
        raise RTaskError, "必要なファイルまたはディレクトリが見つかりませんでした: #{e.message}"
      end

      private

      def fetch_rask_tasks(github_name)
        command = "./rask_cli get_tasks #{github_name} -j"
        stdout, stderr, status = Open3.capture3(command, chdir: @target_dir)

        unless status.success?
          error_msg = stderr.empty? ? "rtask の実行に失敗しましたが，エラーメッセージはありませんでした．" : stderr
          raise RTaskError, error_msg
        end

        list = parse_rtask_json(stdout)
        list.map { |attrs| Resource::RTask.new(attrs) }
      end

      def parse_rtask_json(json_string)
        JSON.parse(json_string)
      rescue JSON::ParserError
        raise RTaskError, "JSON のパースに失敗しました．出力内容を確認してください．"
      end

      def output_tasks(tasks)
        today = Date.today
        this_month_tasks = tasks.select { |task| task.due_this_month?(today) }

        return "表示対象のタスクはありませんでした．" if this_month_tasks.empty?

        grouped = this_month_tasks.group_by { |task| task.due_at.day }
        result = ""

        grouped.keys.sort.each do |day|
          result << "#{today.month}月#{day}日:\n"
          grouped[day].each do |task|
            url = task.url(@rask_url)
            result << "<#{url}|#{task.content}>\n"
          end
        end

        result
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
