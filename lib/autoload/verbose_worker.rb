module VerboseWorker
  def log string
    logger.info { string } if logger
  end

  def debug string
    logger.debug { string } if logger
  end
end

# Monkey Patching so that non-verbose workers won't throw errors.
module Sidekiq
  module Worker
    def log string
    end
    def debug string
    end
  end
end