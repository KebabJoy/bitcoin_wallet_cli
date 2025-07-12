# frozen_string_literal: true

module Infrastructure
  UTXO = Struct.new(:txid, :vout, :value, :confirmed)

  # Repository class to list the UTXO
  class UtxoRepository
    # @param data_gateway [#get]
    def initialize(data_gateway: MempoolClient.new)
      @data_gateway = data_gateway
    end

    def confirmed_balance(address)
      confirmed_for_address(address).sum(&:value)
    end

    def confirmed_for_address(address)
      all_for_address(address).select(&:confirmed)
    end

    def all_for_address(address)
      json = data_gateway.get("address/#{address}/utxo")

      json.map do |h|
        UTXO.new(
          txid: h[:txid],
          vout: h[:vout],
          value: h[:value],
          confirmed: h[:status][:confirmed]
        )
      end
    end

    private

    attr_reader :data_gateway
  end
end
