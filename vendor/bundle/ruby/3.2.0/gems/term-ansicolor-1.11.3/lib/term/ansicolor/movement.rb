require 'tins/terminal'

module Term
  module ANSIColor
    module Movement
      def terminal_lines
        Tins::Terminal.lines
      end

      def terminal_columns
        Tins::Terminal.columns
      end

      def move_to(line = 1, column = 1, string = nil, &block)
        move_command("\e[#{line.to_i};#{column.to_i}H", string, &block)
      end

      def move_to_column(column = 1, string = nil, &block)
        move_command("\e[#{column.to_i}G", string, &block)
      end

      def move_to_line(line = 1, string = nil, &block)
        move_command("\e[#{line.to_i}f", string, &block)
      end

      def move_up(lines = 1, string = nil, &block)
        move_command("\e[#{lines.to_i}A", string, &block)
      end

      def move_down(lines = 1, string = nil, &block)
        move_command("\e[#{lines.to_i}B", string, &block)
      end

      def move_forward(columns = 1, string = nil, &block)
        move_command("\e[#{columns.to_i}C", string, &block)
      end

      def move_backward(columns = 1, string = nil, &block)
        move_command("\e[#{columns.to_i}D", string, &block)
      end

      def move_to_next_line(lines = 1, string = nil, &block)
        move_command("\e[#{lines}E", string, &block)
      end

      def move_to_previous_line(lines = 1, string = nil, &block)
        move_command("\e[#{lines}F", string, &block)
      end

      def move_home(string = nil, &block)
        move_to(1, 1, string, &block)
      end

      def clear_screen(string = nil, &block)
        erase_in_display(2, string, &block)
      end

      def erase_in_display(n = 0, string = nil, &block)
        move_command("\e[#{n}J", string, &block)
      end

      def erase_in_line(n = 0, string = nil, &block)
        move_command("\e[#{n}K", string, &block)
      end

      def scroll_up(pages = 1, string = nil, &block)
        move_command("\e[#{pages}S", string, &block)
      end

      def scroll_down(pages = 1, string = nil, &block)
        move_command("\e[#{pages}T", string, &block)
      end

      def save_position(string = nil, &block)
        move_command("\e[s", string, &block)
      end

      def restore_position(string = nil, &block)
        move_command("\e[u", string, &block)
      end

      def return_to_position(string = nil, &block)
        save_position("") << move_command("", string, &block) << restore_position("")
      end

      def show_cursor(string = nil, &block)
        move_command("\e[?25h", string, &block)
      end

      def hide_cursor(string = nil, &block)
        move_command("\e[?25l", string, &block)
      end

      private

      def move_command(move, string = nil)
        move = move.dup
        if block_given?
          move << yield.to_s
        elsif string.respond_to?(:to_str)
          move << string.to_str
        elsif respond_to?(:to_str)
          move << to_str
        end
        move
      end
    end
  end
end
