require_relative 't02-header-retry'
checks = []
[[[[0,0]], [8], {attempts:1, returned_index:0, returned_status:8}],
 [[[1,1]], [8], {attempts:1, returned_index:0, returned_status:8}],
 [[[1,0],[0,0]], [8,0], {attempts:2, returned_index:1, returned_status:0}],
 [Array.new(4){[1,0]}, [8,8,8,8], {attempts:4, returned_index:4, returned_status:8}],
 [[[1,0]], [0], {attempts:1, returned_index:0, returned_status:0}]].each_with_index do |(headers,statuses,expected), i|
  actual = T02Header.model(headers,statuses)
  raise "Model control #{i} failed" unless actual == expected
  checks << {control:i, kind:'synthetic branch model', actual:actual}
end
bytes = "\0".b * 256
bytes[20,8] = [128,128].pack('V2')
raise 'Metadata control failed' unless T02Header.inspect_bytes(bytes,Digest::SHA256.hexdigest(bytes))[:retry_after_failed_first_lookup] == false
checks << {control:'valid synthetic file', passed:true}
[[bytes,'0'*64], [bytes[0,24],Digest::SHA256.hexdigest(bytes[0,24])], [bytes[0,200],Digest::SHA256.hexdigest(bytes[0,200])]].each do |data,sha|
  begin
    T02Header.inspect_bytes(data,sha)
  rescue RuntimeError => e
    checks << {control:'invalid input', rejection:e.message}
    next
  end
  raise 'Invalid input was accepted'
end
puts JSON.pretty_generate(checks)
