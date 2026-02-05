require 'spec_helper'

describe 'CLI appraisal (with arguments)' do
  before do
    build_appraisal_file <<-Appraisal
      appraise '1.0.0' do
        gem 'dummy', '1.0.0'
      end

      appraise '1.1.0' do
        gem 'dummy', '1.1.0'
      end
    Appraisal

    run 'appraisal install'
    write_file 'test.rb', 'puts "Running: #{$dummy_version}"'
    write_file 'test with spaces.rb', 'puts "Running: #{$dummy_version}"'
  end

  it 'sets APPRAISAL_INITIALIZED environment variable' do
    write_file 'test.rb', <<-TEST_FILE.strip_heredoc
      if ENV['APPRAISAL_INITIALIZED']
        puts "Appraisal initialized!"
      end
    TEST_FILE

    output = run 'appraisal 1.0.0 ruby -rbundler/setup -rdummy test.rb'
    expect(output).to include 'Appraisal initialized!'
  end

  context 'with appraisal name' do
    it 'runs the given command against a correct versions of dependency' do
      output = run 'appraisal 1.0.0 ruby -rbundler/setup -rdummy test.rb'

      expect(output).to include 'Running: 1.0.0'
      expect(output).not_to include 'Running: 1.1.0'
    end
  end

  context 'without appraisal name' do
    it 'runs the given command against all versions of dependency' do
      output = run 'appraisal ruby -rbundler/setup -rdummy test.rb'

      expect(output).to include 'Running: 1.0.0'
      expect(output).to include 'Running: 1.1.0'
    end
  end

  context 'when one of the arguments contains spaces' do
    it 'preserves those spaces' do
      command = 'appraisal 1.0.0 ruby -rbundler/setup -rdummy "test with spaces.rb"'
      output = run(command)
      expect(output).to include 'Running: 1.0.0'
    end
  end
end
