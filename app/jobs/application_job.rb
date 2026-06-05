class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed,
           Net::ReadTimeout, Net::OpenTimeout,
           wait: :exponentially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError
end
