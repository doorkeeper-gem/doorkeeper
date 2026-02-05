module Sprockets
  module Rails
    class LoggerSilenceError < StandardError; end

    class QuietAssets
      def initialize(app)
        @app = app
        @assets_regex = %r(\A/{0,2}#{::Rails.application.config.assets.prefix})
      end

      def call(env)
        if env['PATH_INFO'] =~ @assets_regex
          raise_logger_silence_error unless ::Rails.logger.respond_to?(:silence)

          ::Rails.logger.silence { @app.call(env) }
        else
          @app.call(env)
        end
      end

      private
        def raise_logger_silence_error
          error = "You have enabled `config.assets.quiet`, but your `Rails.logger`\n"
          error << "does not use the `LoggerSilence` module.\n\n"
          error << "Please use a compatible logger such as `ActiveSupport::Logger`\n"
          error << "to take advantage of quiet asset logging.\n\n"

          raise LoggerSilenceError, error
        end
    end
  end
end
