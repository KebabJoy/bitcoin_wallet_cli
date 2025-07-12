# frozen_string_literal: true

module Wallet
  module Domain
    # DTO for private key
    class KeyPair
      attr_reader :key

      # @param key [Bitcoin::Key]
      def initialize(key)
        @key = key
      end

      def address
        key.to_p2wpkh.to_s
      end

      def to_h
        {
          private_key_wif: key.to_wif,
          address: address
        }
      end

      def self.from_wif(wif)
        new(Bitcoin::Key.from_wif(wif))
      end
    end
  end
end
