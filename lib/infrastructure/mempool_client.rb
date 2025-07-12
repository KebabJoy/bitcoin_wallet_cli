# frozen_string_literal: true

require 'faraday'

module Infrastructure
  # Mempool HTTP client implementation
  class MempoolClient
    BASE_URL = ENV.fetch('MEMPOOL_URL', 'https://mempool.space/signet/api')

    def initialize(connection: default_connection)
      @connection = connection
    end

    def get(path)
      response = @connection.get(path)
      raise "HTTP #{response.status} – #{response.body}" unless response.success?

      JSON.parse(response.body, symbolize_names: true)
    end

    def post(path, body)
      response = @connection.post(path, body)
      raise "HTTP #{response.status} – #{response.body}" unless response.success?

      response.body.strip
    end

    private

    def default_connection
      Faraday.new(url: BASE_URL) do |f|
        f.adapter Faraday.default_adapter
        # f.response :logger
      end
    end
  end
end
