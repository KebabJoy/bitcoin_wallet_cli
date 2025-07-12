# frozen_string_literal: true

module Infrastructure
  # Repository class to manage bitcoin transactions
  class TransactionRepository
    # @param data_gateway [#get, #post]
    def initialize(data_gateway: MempoolClient.new)
      @data_gateway = data_gateway
    end

    # @param hex [String] raw hex-encoded transaction
    # @return [String] transaction ID (txid)
    def broadcast_tx(hex)
      data_gateway.post('tx', hex)
    end

    # Retrieves transaction details by txid
    #
    # @param txid [String]
    # @return [Hash]
    def get_tx(txid)
      data_gateway.get("tx/#{txid}")
    end

    private

    attr_reader :data_gateway
  end
end
