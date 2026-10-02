#!/usr/bin/env ruby
# Raw file metadata plus a conditional static prediction; never a board trace.
require 'json'
require 'digest'
module T02Header
  def self.inspect_bytes(bytes, expected_sha)
    sha = Digest::SHA256.hexdigest(bytes)
    raise 'Input SHA-256 mismatch' unless sha == expected_sha
    raise 'Truncated outer header' if bytes.bytesize < 28
    length, offset = bytes.byteslice(20, 8).unpack('V2')
    raise 'Invalid payload bounds' unless offset >= 28 && length >= 128 && offset + length <= bytes.bytesize
    header = bytes.byteslice(offset, 128)
    flag = header.getbyte(0x7f)
    word = header.byteslice(0x18, 4).unpack1('V')
    {sha256: sha, payload_offset: offset, payload_length: length,
     first_header_key_id: header.byteslice(0x38, 16).unpack1('H*'),
     byte_7f: flag, word_18: word,
     retry_after_failed_first_lookup: flag != 0 && word == 0,
     scope: 'Conditional on this exact payload header reaching analysis VA e0a0e8 unchanged; no live execution evidence'}
  end
  def self.model(headers, statuses)
    index = 0
    attempts = 0
    loop do
      raise 'Missing modeled header/status' unless headers[index] && statuses[index]
      flag, word = headers[index]
      status = statuses[index]
      attempts += 1
      break if status == 0 || flag == 0 || word != 0
      index += 1
      break if index == 4
    end
    {attempts: attempts, returned_index: index, returned_status: statuses[attempts - 1]}
  end
end
if $PROGRAM_NAME == __FILE__
  abort 'Usage: ruby t02-header-retry.rb FILE EXPECTED_SHA256' unless ARGV.size == 2
  puts JSON.pretty_generate(T02Header.inspect_bytes(File.binread(ARGV[0]), ARGV[1]))
end
