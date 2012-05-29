DatabaseCleaner[:mongoid].strategy = :truncation
DatabaseCleaner[:mongoid].clean_with :truncation
