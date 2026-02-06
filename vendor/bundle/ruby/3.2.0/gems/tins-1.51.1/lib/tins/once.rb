module Tins
  # A module for ensuring exclusive execution of code blocks using file-based
  # locking.
  #
  # This module provides mechanisms to prevent multiple instances of a script
  # from running simultaneously by using file system locks on the script itself
  # or a specified lock file.
  #
  # @example Basic usage with automatic lock file detection
  #   Tins::Once.only_once do
  #     # Critical section - only one instance runs at a time
  #     perform_backup()
  #   end
  #
  # @example Using custom lock file
  #   Tins::Once.only_once("/var/run/myapp.lock") do
  #     # Custom lock file
  #     process_data()
  #   end
  #
  # @example Non-blocking attempt
  #   begin
  #     Tins::Once.try_only_once do
  #       # Will raise if another instance holds the lock
  #       update_cache()
  #     end
  #   rescue => e
  #     puts "Another instance is running"
  #   end
  module Once
    include File::Constants

    # Executes a block of code exclusively, ensuring only one instance runs at
    # a time.
    #
    # Uses the script name (or specified lock file) as the locking mechanism.
    # The first invocation will acquire an exclusive lock and execute the
    # block, while subsequent invocations will block until the lock is
    # released.
    #
    # @param lock_filename [String] Optional custom lock filename.
    #   Defaults to `$0` (the script name), which means the script itself
    #   is used as the lock file.
    # @param locking_constant [Integer] File locking constant.
    #   Defaults to `LOCK_EX` for exclusive locking.
    # @yield [void] The block of code to execute exclusively
    # @return [Object] The return value of the yielded block
    # @raise [Errno::ENOENT] If the lock file doesn't exist
    # @raise [SystemCallError] If file locking fails
    def only_once(lock_filename = nil, locking_constant = nil)
      lock_filename ||= $0
      locking_constant ||= LOCK_EX
      f = File.new(lock_filename, RDONLY)
      f.flock(locking_constant) and yield
    ensure
      if f
        f.flock LOCK_UN
        f.close
      end
    end

    # Attempts to execute a block of code exclusively, but fails immediately
    # if another instance holds the lock.
    #
    # This is a non-blocking version that will raise an exception if the lock
    # cannot be acquired immediately.
    #
    # @param lock_filename [String] Optional custom lock filename.
    #   Defaults to `$0` (the script name).
    # @param locking_constant [Integer] File locking constant.
    #   Defaults to `LOCK_EX | LOCK_NB` for non-blocking exclusive locking.
    # @yield [void] The block of code to execute exclusively
    # @return [Object] The return value of the yielded block
    # @raise [Errno::EAGAIN] If another process holds the lock
    # @raise [Errno::ENOENT] If the lock file doesn't exist
    def try_only_once(lock_filename = nil, locking_constant = nil, &block)
      only_once(lock_filename, locking_constant || LOCK_EX | LOCK_NB, &block)
    end

    module_function :only_once, :try_only_once
  end
end
