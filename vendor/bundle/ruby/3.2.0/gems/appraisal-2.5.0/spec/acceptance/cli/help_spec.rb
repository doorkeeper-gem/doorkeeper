require 'spec_helper'

describe 'CLI', 'appraisal help' do
  it 'prints usage along with commands, and list of appraisals' do
    build_appraisal_file <<-Appraisal
      appraise '1.0.0' do
        gem 'dummy', '1.0.0'
      end
    Appraisal

    output = run 'appraisal help'

    expect(output).to include 'Usage:'
    expect(output).to include 'appraisal [APPRAISAL_NAME] EXTERNAL_COMMAND'
    expect(output).to include '1.0.0'
  end

  it 'prints out usage even Appraisals file does not exist' do
    output = run 'appraisal help'

    expect(output).to include 'Usage:'
    expect(output).not_to include 'Unable to locate'
  end
end
