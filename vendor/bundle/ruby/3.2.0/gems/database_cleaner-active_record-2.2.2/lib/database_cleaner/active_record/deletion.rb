module DatabaseCleaner
  module ActiveRecord
    class Deletion < Truncation
      def clean
        connection.disable_referential_integrity do
          if pre_count? && connection.respond_to?(:pre_count_tables)
            delete_tables(connection, connection.pre_count_tables(tables_to_clean(connection)))
          else
            delete_tables(connection, tables_to_clean(connection))
          end
        end

        connection_class.connection_pool.release_connection
      end

      private

      def delete_tables(connection, table_names)
        table_names.each do |table_name|
          delete_table(connection, table_name)
          reset_id_sequence(connection, table_name) if @reset_ids
        end
      end

      def delete_table connection, table_name
        connection.execute("DELETE FROM #{connection.quote_table_name(table_name)} WHERE 1=1")
      end

      def reset_id_sequence connection, table_name
        case connection.adapter_name
        when 'Mysql2', 'Trilogy'
          connection.execute("ALTER TABLE #{table_name} AUTO_INCREMENT = 1;")
        when 'SQLite'
          connection.execute("delete from sqlite_sequence where name='#{table_name}';")
        when 'PostgreSQL'
          connection.reset_pk_sequence!(table_name)
        else
          raise "reset_id option not supported for #{connection.adapter_name}"
        end
      end

      def tables_to_clean(connection)
        if information_schema_exists?(connection)
          @except += connection.database_cleaner_view_cache + migration_storage_names
          (@only.any? ? @only : tables_with_new_rows(connection)) - @except
        else
          super
        end
      end

      def tables_with_new_rows(connection)
        stats = table_stats_query(connection)
        if stats != ''
          connection.select_values(stats)
        else
          []
        end
      end

      def table_stats_query(connection)
        @table_stats_query ||= build_table_stats_query(connection)
      ensure
        @table_stats_query = nil unless @cache_tables
      end

      def build_table_stats_query(connection)
        tables = connection.select_values(<<-SQL)
          SELECT table_name
          FROM information_schema.tables
          WHERE table_schema = database()
          AND #{self.class.exclusion_condition('table_name')};
        SQL
        queries = tables.map do |table|
          "(SELECT #{connection.quote(table)} FROM #{connection.quote_table_name(table)} LIMIT 1)"
        end
        queries.join(' UNION ALL ')
      end

      def information_schema_exists? connection
        ["Mysql2", "Trilogy"].include?(connection.adapter_name)
      end
    end
  end
end
