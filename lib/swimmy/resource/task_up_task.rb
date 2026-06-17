require 'time'

module Swimmy
  module Resource
    class TaskUpTask
      attr_reader :id, :content, :due_at

      def initialize(attributes)
        @id = attributes["id"]
        @content = attributes["content"]
        @due_at = parse_due_at(attributes["due_at"])
      end

      def due_this_month?(base_date)
        return false unless due_at
        due_at.year == base_date.year && due_at.month == base_date.month
      end

      def start_time_as_string
        (due_at - 3600).strftime("%Y/%m/%d/%H:%M")
      end

      def end_time_as_string
        due_at.strftime("%Y/%m/%d/%H:%M")
      end

      private

      def parse_due_at(value)
        return nil if value.nil? || value.empty?
        Time.parse(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
