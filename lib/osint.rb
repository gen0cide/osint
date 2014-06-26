require "osint/version"
require "osint/lists"
require "typhoeus"
require "pry"
require "semantic_logger"

module Osint
  class Attack
    def initialize(target_url, concurrency=10, log_level=:info)
      SemanticLogger.default_level = log_level
      SemanticLogger.add_appender(STDOUT, &SemanticLogger::Appender::Base.colorized_formatter)      
      @logger = SemanticLogger[target_url]      
      @hydra = Typhoeus::Hydra.new(max_concurrency: concurrency)
      @uri = URI(target_url)
      @base_url = "#{@uri.scheme}://#{@uri.host}:#{@uri.port}#{@uri.path}"
      Osint::Lists::ALL.each do |uri|
        request = Typhoeus::Request.new(File.join(@base_url, uri), followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0)
        request.on_complete do |response|
          if response.code == 200
            @logger.info "[200] #{response.effective_url}"
          elsif response.timed_out?
            @logger.debug "[TIMEOUT] #{response.effective_url}"
          elsif response.code == 400
            @logger.debug "[400] #{response.effective_url}"
          elsif response.code == 404
            @logger.debug "[404] #{response.effective_url}"
          elsif response.code == 500
            @logger.debug "[500] #{response.effective_url}"
          elsif response.code == 401
            @logger.debug "[401] #{response.effective_url}"
          elsif response.code > 0
            @logger.debug "[#{response.code}] #{response.effective_url}"
          else
            @logger.error "Something went wrong: #{response.effective_url}"
          end
        end
        @hydra.queue(request)
      end
      @logger.info "Queued #{@hydra.queued_requests.length} Requests... Lets begin!"                  
    end

    def hit_it
      @hydra.run
    end
  end
end
