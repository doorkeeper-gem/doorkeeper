module OAuth
  module RandomString
    def random_string
      SecureRandom.hex(32)
    end

    def unique_random_string_for(attribute)
      loop do
        token = random_string
        break token unless self.class.send("find_by_#{attribute}", token)
      end
    end
  end
end

