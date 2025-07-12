# frozen_string_literal: true

require 'bitcoin'

class BitcoinWallet
  LIB_PATH = Pathname.new(__dir__)

  def self.load!
    Dir[LIB_PATH.join('**/*.rb')].each do |file|
      require file
    end
  end
end

BitcoinWallet.load!
