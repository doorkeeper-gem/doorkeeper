# frozen_string_literal: true

require 'pathname'

module Coveralls
  module SimpleCov
    class Formatter
      def display_result(result) # rubocop:disable Naming/PredicateMethod
        # Log which files would be submitted.
        if result.files.empty?
          Coveralls::Output.puts '[Coveralls] There are no covered files.', color: 'yellow'
        else
          Coveralls::Output.puts '[Coveralls] Some handy coverage stats:'
        end

        result.files.each do |f|
          Coveralls::Output.print '  * '
          Coveralls::Output.print short_filename(f.filename).to_s, color: 'cyan'
          Coveralls::Output.print ' => ', color: 'white'
          cov = "#{f.covered_percent.round}%"
          if f.covered_percent > 90
            Coveralls::Output.print cov, color: 'green'
          elsif f.covered_percent > 80
            Coveralls::Output.print cov, color: 'yellow'
          else
            Coveralls::Output.print cov, color: 'red'
          end
          Coveralls::Output.puts ''
        end

        true
      end

      def get_source_files(result)
        # Gather the source files.
        source_files = []
        result.files.each do |file|
          properties = {}

          # Get Source
          properties[:source] = File.open(file.filename, 'rb:utf-8').read

          # Get the root-relative filename
          properties[:name] = short_filename(file.filename)

          # Get the coverage
          properties[:coverage] = file.coverage_data['lines']
          properties[:branches] = branches(file.coverage_data['branches']) if file.coverage_data['branches']

          # Skip nocov lines
          file.lines.each_with_index do |line, i|
            properties[:coverage][i] = nil if line.skipped?
          end

          source_files << properties
        end

        source_files
      end

      def branches(simplecov_branches)
        branches_properties = []
        simplecov_branches.each do |branch_data, data|
          branch_number = 0
          line_number = branch_data.split(', ')[2].to_i
          data.each_value do |hits|
            branch_number += 1
            branches_properties.push(line_number, 0, branch_number, hits)
          end
        end
        branches_properties
      end

      def format(result)
        unless Coveralls.should_run?
          display_result result if Coveralls.noisy?

          return
        end

        # Post to Coveralls.
        API.post_json 'jobs',
                      source_files:   get_source_files(result),
                      test_framework: result.command_name.downcase,
                      run_at:         result.created_at

        Coveralls::Output.puts output_message result

        true
      rescue StandardError => e
        display_error e
      end

      def display_error(error) # rubocop:disable Naming/PredicateMethod
        Coveralls::Output.puts 'Coveralls encountered an exception:', color: 'red'
        Coveralls::Output.puts error.class.to_s, color: 'red'
        Coveralls::Output.puts error.message, color: 'red'

        error.backtrace&.each do |line|
          Coveralls::Output.puts line, color: 'red'
        end

        if error.respond_to?(:response) && error.response
          Coveralls::Output.puts error.response.to_s, color: 'red'
        end

        false
      end

      def output_message(result)
        "Coverage is at #{begin
          result.covered_percent.round(2)
        rescue StandardError
          result.covered_percent.round
        end}%.\nCoverage report sent to Coveralls."
      end

      def short_filename(filename)
        return filename unless ::SimpleCov.root

        filename = Pathname.new(filename)
        root = Pathname.new(::SimpleCov.root)
        filename.relative_path_from(root).to_s
      end
    end
  end
end
