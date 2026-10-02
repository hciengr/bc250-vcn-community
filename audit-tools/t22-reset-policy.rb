#!/usr/bin/env ruby
require 'json'
require 'digest'
abort 'Usage: ruby t22-reset-policy.rb RESEARCH_WORKSPACE' unless ARGV.size==1
root=File.expand_path(ARGV[0])
inputs={
 'firmware/smu/smu_fw_robin_1_trim'=>'8c29cf0b1c5ea713f1f8ae95ed4c1dc547d00c530530c131950cfd5eb08c6675',
 'exports/pmfw-p3-const-full/functions.jsonl'=>'617754c44bbc01d7e066429ad29bf24341728375495e7a664875e8c0177fee07',
 'exports/pmfw-p3-const-full/state-evidence.asm'=>'4f8b8f574c686e59d245647d3d1736af7b6057c5b5c6efd502319aa4812716ae'}
inputs.each{|path,sha|abort "Missing/changed input: #{path}" unless File.file?(File.join(root,path))&&Digest::SHA256.file(File.join(root,path)).hexdigest==sha}
functions=File.readlines(File.join(root,inputs.keys[1])).map{|line|JSON.parse(line)}.to_h{|f|[f['entry'],f]}
walks=%w[0002ad78 00029d04 0002b018 0002c10c 0002e0e8 0002e3e8].map do |entry|
  queue=[[entry]];seen={};missing=[];indirect=[]
  until queue.empty?
    path=queue.shift;id=path.last;next if seen.key?(id);seen[id]=path
    f=functions[id];unless f;missing<<id;next;end
    indirect<<{entry:id,sites:f['indirect_calls']} unless f['indirect_calls'].empty?
    f['calls'].each{|call|queue<<path+[call['entry']]}
  end
  {root:entry,nodes:seen.size,missing:missing,indirect:indirect,target_paths:%w[0002e69c 0002e448].to_h{|id|[id,seen[id]]}}
end
writers=functions.values.flat_map{|f|f['references'].filter_map{|r|{function:f['entry'],at:r['at'],target:r['to'],instruction:f['memory_writes'].find{|w|w['at']==r['at']}&.dig('instruction')} if r['type']=='WRITE'&&%w[00013ed4 00013ed8].include?(r['to'])}}
raise 'Changed resolved writer inventory' unless writers.map{|w|w[:at]}.sort==%w[0002e4ff 0002e6ad]
asm=File.read(File.join(root,inputs.keys[2]))
raise 'Missing requested-state store evidence' unless asm.include?('0002e6ad  s32i.n a2,a8,0x4')
bin=File.binread(File.join(root,inputs.keys[0]))
raise 'Changed gate initialization' unless bin.byteslice(0x13ed4,8).unpack('V2')==[8,0]
models=[[8,0],[0,0],[1,0]].map{|current,request|{kind:'synthetic state-gate calculation',current_before:current,policy_state:request,requested_after:request,worker_would_enter:current!=request,current_after_if_worker_completes:request}}
puts JSON.pretty_generate({kind:'bounded static inventory plus synthetic state cases',inputs:inputs,gate_image:[8,0],policy_copy_callers:functions['0002e69c']['called_by'],resolved_gate_writers:writers,direct_call_walks:walks,models:models,raw_writer_bytes:writers.to_h{|w|[w[:at],bin.byteslice(w[:at].to_i(16),2).unpack1('H*')]},limits:'Graph reachability is not feasible execution. Resolved WRITE references are not exhaustive alias analysis. SSIP is preferred static interpretation; neither SSIP/SSIU is runtime validated. No soft-reset entry was identified as invoking this path.'})
