# frozen_string_literal: true

module Wallet
  # Bitcoin-address' private key repository class
  class FileKeyRepository
    DEFAULT_PATH = 'data/wallet.json'

    def initialize(path = DEFAULT_PATH)
      @path = path
    end

    # @return [Domain::KeyPair, nil]
    def load
      return unless persisted?

      json = JSON.parse(File.read(@path))
      Domain::KeyPair.from_wif(json['private_key_wif'])
    end

    # @param key_pair [Domain::KeyPair]
    def save(key_pair)
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, key_pair.to_h.to_json)
    end

    # @return [Boolean]
    def persisted?
      File.exist?(@path)
    end
  end
end
