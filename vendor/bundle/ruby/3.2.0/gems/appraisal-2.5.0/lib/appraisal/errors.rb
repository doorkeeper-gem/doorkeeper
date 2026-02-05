module Appraisal
  # Raises when Appraisal is unable to locate Appraisals file in the current directory.
  class AppraisalsNotFound < StandardError
    def message
      "Unable to locate 'Appraisals' file in the current directory."
    end
  end
end
