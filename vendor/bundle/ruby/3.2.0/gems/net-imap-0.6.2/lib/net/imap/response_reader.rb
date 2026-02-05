# frozen_string_literal: true

module Net
  class IMAP
    # See https://www.rfc-editor.org/rfc/rfc9051#section-2.2.2
    class ResponseReader # :nodoc:
      attr_reader :client

      def initialize(client, sock)
        @client, @sock = client, sock
      end

      def read_response_buffer
        @buff = String.new
        catch :eof do
          while true
            read_line
            break unless (@literal_size = get_literal_size)
            read_literal
          end
        end
        buff
      ensure
        @buff = nil
      end

      private

      attr_reader :buff, :literal_size

      def bytes_read          = buff.bytesize
      def empty?              = buff.empty?
      def done?               = line_done? && !get_literal_size
      def line_done?          = buff.end_with?(CRLF)
      def get_literal_size    = /\{(\d+)\}\r\n\z/n =~ buff && $1.to_i

      def read_line
        buff << (@sock.gets(CRLF, read_limit) or throw :eof)
        max_response_remaining! unless line_done?
      end

      def read_literal
        # check before allocating memory for literal
        max_response_remaining!
        literal = String.new(capacity: literal_size)
        buff << (@sock.read(read_limit(literal_size), literal) or throw :eof)
      ensure
        @literal_size = nil
      end

      def read_limit(limit = nil)
        [limit, max_response_remaining!].compact.min
      end

      def max_response_size      = client.max_response_size
      def max_response_remaining = max_response_size &.- bytes_read
      def response_too_large?    = max_response_size &.< min_response_size
      def min_response_size      = bytes_read + min_response_remaining

      def min_response_remaining
        empty? ? 3 : done? ? 0 : (literal_size || 0) + 2
      end

      def max_response_remaining!
        return max_response_remaining unless response_too_large?
        raise ResponseTooLargeError.new(
          max_response_size:, bytes_read:, literal_size:,
        )
      end

    end
  end
end
