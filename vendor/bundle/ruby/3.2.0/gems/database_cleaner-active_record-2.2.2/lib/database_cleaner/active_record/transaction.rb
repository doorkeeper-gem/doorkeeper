module DatabaseCleaner
  module ActiveRecord
    class Transaction < Base
      def start
        connection = if ::ActiveRecord.version >= Gem::Version.new("7.2")
          connection_class.lease_connection
        else
          connection_class.connection
        end

        # Hack to make sure that the connection is properly set up before cleaning
        connection.transaction {}

        connection.begin_transaction joinable: false
      end


      def clean
        connection_class.connection_pool.connections.each do |connection|
          connection.lock.synchronize do
            next unless connection.open_transactions > 0
            connection.rollback_transaction
          end
        end

        connection_class.connection_pool.release_connection
      end
    end
  end
end
