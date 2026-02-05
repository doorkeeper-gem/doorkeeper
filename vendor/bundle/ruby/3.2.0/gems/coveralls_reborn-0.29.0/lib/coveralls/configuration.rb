# frozen_string_literal: true

require 'yaml'
require 'securerandom'

module Coveralls
  module Configuration
    class << self
      def configuration
        config = {
          environment: relevant_env,
          git:         git
        }

        yml = yaml_config

        if yml
          config[:configuration] = yml
          config[:repo_token] = yml['repo_token'] || yml['repo_secret_token']
        end

        if ENV['COVERALLS_REPO_TOKEN']
          config[:repo_token] = ENV['COVERALLS_REPO_TOKEN']
        end

        if ENV['COVERALLS_PARALLEL'] && ENV['COVERALLS_PARALLEL'] != 'false'
          config[:parallel] = true
        end

        if ENV['COVERALLS_FLAG_NAME']
          config[:flag_name] = ENV['COVERALLS_FLAG_NAME']
        end

        if ENV['TRAVIS']
          define_service_params_for_travis(config, yml ? yml['service_name'] : nil)
        elsif ENV['CIRCLECI']
          define_service_params_for_circleci(config)
        elsif ENV['SEMAPHORE']
          define_service_params_for_semaphore(config)
        elsif ENV['JENKINS_URL'] || ENV['JENKINS_HOME']
          define_service_params_for_jenkins(config)
        elsif ENV['APPVEYOR']
          define_service_params_for_appveyor(config)
        elsif ENV['TDDIUM']
          define_service_params_for_tddium(config)
        elsif ENV['GITLAB_CI']
          define_service_params_for_gitlab(config)
        elsif ENV['BUILDKITE']
          define_service_params_for_buildkite(config)
        elsif ENV['COVERALLS_RUN_LOCALLY'] || Coveralls.testing
          define_service_params_for_coveralls_local(config)
        end

        # standardized env vars
        define_standard_service_params_for_generic_ci(config)

        if ENV['COVERALLS_SERVICE_NAME']
          config[:service_name] = ENV['COVERALLS_SERVICE_NAME']
        end

        config
      end

      def define_service_params_for_travis(config, service_name)
        config[:service_job_id]       = ENV['TRAVIS_JOB_ID']
        config[:service_pull_request] = ENV['TRAVIS_PULL_REQUEST'] unless ENV['TRAVIS_PULL_REQUEST'] == 'false'
        config[:service_name]         = service_name || 'travis-ci'
        config[:service_branch]       = ENV['TRAVIS_BRANCH']
      end

      def define_service_params_for_circleci(config)
        config[:service_name]         = 'circleci'
        config[:service_number]       = ENV['CIRCLE_WORKFLOW_ID']
        config[:service_pull_request] = ENV['CI_PULL_REQUEST'].split('/pull/')[1] unless ENV['CI_PULL_REQUEST'].nil?
        config[:service_job_number]   = ENV['CIRCLE_BUILD_NUM']
        config[:git_commit]           = ENV['CIRCLE_SHA1']
        config[:git_branch]           = ENV['CIRCLE_BRANCH']
      end

      def define_service_params_for_semaphore(config)
        config[:service_name]         = 'semaphore'
        config[:service_number]       = ENV['SEMAPHORE_WORKFLOW_ID']
        config[:service_job_id]       = ENV['SEMAPHORE_JOB_ID']
        config[:service_build_url]    = "#{ENV['SEMAPHORE_ORGANIZATION_URL']}/jobs/#{ENV['SEMAPHORE_JOB_ID']}"
        config[:service_branch]       = ENV['SEMAPHORE_GIT_WORKING_BRANCH']
        config[:service_pull_request] = ENV['SEMAPHORE_GIT_PR_NUMBER']
      end

      def define_service_params_for_jenkins(config)
        config[:service_name]         = 'jenkins'
        config[:service_number]       = ENV['BUILD_NUMBER']
        config[:service_branch]       = ENV['BRANCH_NAME']
        config[:service_pull_request] = ENV['ghprbPullId']
      end

      def define_service_params_for_appveyor(config)
        config[:service_name]      = 'appveyor'
        config[:service_number]    = ENV['APPVEYOR_BUILD_VERSION']
        config[:service_branch]    = ENV['APPVEYOR_REPO_BRANCH']
        config[:commit_sha]        = ENV['APPVEYOR_REPO_COMMIT']
        repo_name                  = ENV['APPVEYOR_REPO_NAME']
        config[:service_build_url] = format('https://ci.appveyor.com/project/%<repo_name>s/build/%<service_number>s', repo_name: repo_name, service_number: config[:service_number])
      end

      def define_service_params_for_tddium(config)
        config[:service_name]         = 'tddium'
        config[:service_number]       = ENV['TDDIUM_SESSION_ID']
        config[:service_job_number]   = ENV['TDDIUM_TID']
        config[:service_pull_request] = ENV['TDDIUM_PR_ID']
        config[:service_branch]       = ENV['TDDIUM_CURRENT_BRANCH']
        config[:service_build_url]    = "https://ci.solanolabs.com/reports/#{ENV['TDDIUM_SESSION_ID']}"
      end

      def define_service_params_for_gitlab(config)
        config[:service_name]       = 'gitlab-ci'
        config[:service_number]     = ENV['CI_PIPELINE_ID']
        config[:service_job_number] = ENV['CI_BUILD_NAME']
        config[:service_job_id]     = ENV['CI_BUILD_ID']
        config[:service_branch]     = ENV['CI_BUILD_REF_NAME']
        config[:commit_sha]         = ENV['CI_BUILD_REF']
      end

      def define_service_params_for_buildkite(config)
        config[:service_name]         = 'buildkite'
        config[:service_number]       = ENV['BUILDKITE_BUILD_NUMBER']
        config[:service_job_id]       = ENV['BUILDKITE_BUILD_ID']
        config[:service_branch]       = ENV['BUILDKITE_BRANCH']
        config[:service_build_url]    = ENV['BUILDKITE_BUILD_URL']
        config[:service_pull_request] = ENV['BUILDKITE_PULL_REQUEST']
        config[:commit_sha]           = ENV['BUILDKITE_COMMIT']
      end

      def define_service_params_for_coveralls_local(config)
        config[:service_job_id]     = nil
        config[:service_name]       = 'coveralls-ruby'
        config[:service_event_type] = 'manual'
      end

      def define_standard_service_params_for_generic_ci(config)
        config[:service_name]         ||= ENV['CI_NAME']
        config[:service_number]       ||= ENV['CI_BUILD_NUMBER']
        config[:service_job_id]       ||= ENV['CI_JOB_ID']
        config[:service_build_url]    ||= ENV['CI_BUILD_URL']
        config[:service_branch]       ||= ENV['CI_BRANCH']
        config[:service_pull_request] ||= (ENV['CI_PULL_REQUEST'] || '')[/(\d+)$/, 1]
      end

      def yaml_config
        return unless configuration_path && File.exist?(configuration_path)

        YAML.load_file(configuration_path)
      end

      def configuration_path
        return unless root

        File.expand_path(File.join(root, '.coveralls.yml'))
      end

      def root
        pwd
      end

      def pwd
        Dir.pwd
      end

      def simplecov_root
        return unless defined?(::SimpleCov)

        ::SimpleCov.root
      end

      def rails_root
        Rails.root.to_s
      rescue StandardError
        nil
      end

      def git
        hash = {}

        Dir.chdir(root) do
          hash[:head] = {
            id:              ENV.fetch('GIT_ID', `git log -1 --pretty=format:'%H'`),
            author_name:     ENV.fetch('GIT_AUTHOR_NAME', `git log -1 --pretty=format:'%aN'`),
            author_email:    ENV.fetch('GIT_AUTHOR_EMAIL', `git log -1 --pretty=format:'%ae'`),
            committer_name:  ENV.fetch('GIT_COMMITTER_NAME', `git log -1 --pretty=format:'%cN'`),
            committer_email: ENV.fetch('GIT_COMMITTER_EMAIL', `git log -1 --pretty=format:'%ce'`),
            message:         ENV.fetch('GIT_MESSAGE', `git log -1 --pretty=format:'%s'`)
          }

          # Branch
          hash[:branch] = ENV.fetch('GIT_BRANCH', `git rev-parse --abbrev-ref HEAD`)

          # Remotes
          remotes = nil
          begin
            remotes = `git remote -v`.split("\n").map do |remote|
              splits = remote.split.compact
              { name: splits[0], url: splits[1] }
            end.uniq
          rescue StandardError => e
            # TODO: Add error action
            puts e.message
          end

          hash[:remotes] = remotes
        end

        hash
      rescue StandardError => e
        Coveralls::Output.puts 'Coveralls git error:', color: 'red'
        Coveralls::Output.puts e.to_s, color: 'red'
        nil
      end

      def relevant_env
        base_env = {
          pwd:            pwd,
          rails_root:     rails_root,
          simplecov_root: simplecov_root,
          gem_version:    VERSION
        }

        service_env =
          if ENV['TRAVIS']
            travis_env_hash
          elsif ENV['CIRCLECI']
            circleci_env_hash
          elsif ENV['JENKINS_URL']
            jenkins_env_hash
          elsif ENV['SEMAPHORE']
            semaphore_env_hash
          else
            {}
          end

        base_env.merge! service_env
      end

      private

      def circleci_env_hash
        {
          circleci_build_num: ENV['CIRCLE_BUILD_NUM'],
          branch:             ENV['CIRCLE_BRANCH'],
          commit_sha:         ENV['CIRCLE_SHA1']
        }
      end

      def jenkins_env_hash
        {
          jenkins_build_num: ENV['BUILD_NUMBER'],
          jenkins_build_url: ENV['BUILD_URL'],
          branch:            ENV['GIT_BRANCH'],
          commit_sha:        ENV['GIT_COMMIT']
        }
      end

      def semaphore_env_hash
        {
          branch:     ENV['BRANCH_NAME'],
          commit_sha: ENV['REVISION']
        }
      end

      def travis_env_hash
        {
          travis_job_id:       ENV['TRAVIS_JOB_ID'],
          travis_pull_request: ENV['TRAVIS_PULL_REQUEST'],
          branch:              ENV['TRAVIS_BRANCH']
        }
      end
    end
  end
end
