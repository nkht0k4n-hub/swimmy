require 'open3'

module Swimmy
  module Command
    class Rask < Swimmy::Command::Base

            command "rask" do |client, data, match|
              begin
               target_dir="/home/nakahata/git/rask_cli"
               stdout,stderr,status= Open3.capture3("cargo run -- rask aaa",chdir: target_dir)
               if status.success?
                  msg=stdout.empty? ? "raskの実行に成功しましたが、出力はありませんでした。" : stdout
                  client.say(channel: data.channel, text: msg)
                else
                  error_msg = stderr.empty? ? "raskの実行に失敗しましたが、エラーメッセージはありませんでした。" : stderr
                  client.say(channel: data.channel, text: error_msg)
                end
              rescue Errno::ENOENT
                client.say(channel: data.channel, text: "ディレクトリが見つかりません")
              rescue => e
                client.say(channel: data.channel, text: "raskの実行に失敗しました")
              end
            end
    end
  end
end

      
