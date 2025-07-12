# frozen_string_literal: true

module Wallet
  # Bitcoin transactions builder
  class TransactionBuilder
    FIXED_FEE_SATS = 1_000 # 0.00001BTC

    # @param key_pair [Wallet::KeyManager] provides key & address
    # @param utxo_repo [Infrastructure::UtxoRepository]
    # @param tx_repo [Infrastructure::TransactionRepository]
    def initialize(key_pair:,
                   utxo_repo: Infrastructure::UtxoRepository.new,
                   tx_repo: Infrastructure::TransactionRepository.new)
      @key_pair = key_pair
      @utxo_repo = utxo_repo
      @tx_repo = tx_repo
    end

    # @param dest_address [String] base58 or bech32 Signet address
    # @param amount_sats [Integer]
    # @return [String] txid
    def send_to(dest_address, amount_sats)
      utxos = utxo_repo.confirmed_for_address(key_pair.address)
      relevant_utxo, change = select_utxos(utxos, amount_sats + FIXED_FEE_SATS)
      raise 'Not enough money👎👎👎' unless relevant_utxo

      tx = build_tx(relevant_utxo, dest_address, amount_sats, change)
      tx_repo.broadcast_tx(tx.to_hex.to_s)
    end

    private

    attr_reader :key_pair, :utxo_repo, :tx_repo

    # @return [Array<(Array<Wallet::UTXO>, Integer), nil>]
    def select_utxos(utxos, target)
      total = 0
      chosen = []
      utxos.sort_by(&:value).each do |u|
        chosen << u
        total += u.value
        break if total >= target
      end

      return nil unless total >= target

      [chosen, total - target]
    end

    # @return [Bitcoin::Tx]
    def build_tx(relevant_utxo, dest_address, amount_sats, change_sats) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      tx = Bitcoin::Tx.new

      relevant_utxo.each do |u|
        out_point = Bitcoin::OutPoint.from_txid(u.txid, u.vout)

        tx.in << Bitcoin::TxIn.new(out_point:)
      end

      tx.out << Bitcoin::TxOut.new(value: amount_sats, script_pubkey: Bitcoin::Script.parse_from_addr(dest_address))
      tx.out << Bitcoin::TxOut.new(value: change_sats, script_pubkey: Bitcoin::Script.parse_from_addr(key_pair.address)) if change_sats.positive?

      pk_script = Bitcoin::Script.to_p2pkh(key_pair.key.hash160)
      relevant_utxo.each_index do |idx|
        sig_hash = tx.sighash_for_input(idx, pk_script)
        signature = key_pair.key.sign(sig_hash) + [Bitcoin::SIGHASH_TYPE[:all]].pack('C')

        # signature for legacy tx according to https://github.com/chaintope/bitcoinrb/wiki/Transaction
        tx.in[idx].script_sig << signature
        tx.in[idx].script_sig << key_pair.key.pubkey.htb
      end

      tx
    end
  end
end
