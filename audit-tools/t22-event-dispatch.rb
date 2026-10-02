#!/usr/bin/env ruby
require 'json'
require 'digest'
abort 'Usage: ruby t22-event-dispatch.rb RESEARCH_WORKSPACE' unless ARGV.size == 1
root=File.expand_path(ARGV[0])
inputs={"firmware/smu/smu_fw_robin_1_trim"=>"8c29cf0b1c5ea713f1f8ae95ed4c1dc547d00c530530c131950cfd5eb08c6675", "exports/pmfw-p3-const-full/functions.jsonl"=>"617754c44bbc01d7e066429ad29bf24341728375495e7a664875e8c0177fee07", "exports/pmfw-p3-const-full/decompiled/0001b024.c"=>"b54d9589a2f1e8551f561ca0da108fc54842a720b9a6796c2c0392e425957ff4", "exports/pmfw-p3-const-full/decompiled/00039db4.c"=>"0d019589ee29e419a9f5b449be70f7db2aa76eda58d7698fb257e7c92213dd66", "exports/pmfw-p3-const-full/decompiled/00039c04.c"=>"9cc1fc4ea75d86a0be2cecab7b964a84fc2f62ca22bce928ac51a3db97d1f43f", "exports/pmfw-p3-const-full/decompiled/00001e18.c"=>"a2550ed0e63aff4b87a48f0ed94f2bb1e04916f4ec3792ca4fc31c2142cc0bbc", "exports/pmfw-p3-const-full/decompiled/000028f8.c"=>"6630c4333d0306c445e74e72123755b00413dec869cdeca8772455455c0ee2f9", "exports/pmfw-p3-const-full/decompiled/00001024.c"=>"057d4288da2c4e7320348386af6a65d2f12f18e739c5124fb6fab1601eb662db", "exports/pmfw-p3-const-full/decompiled/000026b4.c"=>"43de1570e4bc49f231eb2bdbbdc9c67c3280fcf71a2e18cdcac95e19b5bcd668", "exports/pmfw-p3-const-full/decompiled/0001b154.c"=>"a1ce6527918edd580fb9d27b33e4984366530c0acb253e1d6fd820eb679b5e39"}
inputs.each do |path,sha|
  full=File.join(root,path)
  abort "Missing input: #{path}" unless File.file?(full)
  abort "Changed input: #{path}" unless Digest::SHA256.file(full).hexdigest==sha
end
bin=File.binread(File.join(root,inputs.keys[0]))
fs=File.foreach(File.join(root,inputs.keys[1])).map{|l|JSON.parse(l)}.to_h{|f|[f['entry'],f]}
expected={0x17078=>0x1024,0x17074=>0x61a8,0x18714=>0xab70,0xca4=>0xab70,0x18730=>0x03200380,0x18734=>0x03200410,0xba4=>0x1b154,0x17090=>0xc700,0x17098=>0xc7a0}
literals=expected.map do |offset,value|
  actual=bin.byteslice(offset,4).unpack1('V')
  abort 'Changed literal relation' unless actual==value
  {address:'%08x'%offset,value:'%08x'%actual,bytes:bin.byteslice(offset,4).unpack1('H*')}
end
raise 'Missing handler dispatch site' unless fs['00001e18']['indirect_calls'].any?{|x|x['at']=='00001e57'}
raise 'Missing dispatcher queue call' unless fs['00001024']['calls'].any?{|x|x['entry']=='000026b4'}
puts JSON.pretty_generate({kind:'static source/literal cross-check; address arithmetic is synthetic',inputs:inputs,literals:literals,handler_index:96,handler_slot:'%08x'%(0xab70+96*4),callback_slot24:'%08x'%(0xc700+24*4),callback_count:(0xc7a0-0xc700)/4,parameter_value:0x61a8,parameter_units:'unestablished',dispatch_site:fs['00001e18']['indirect_calls'],sources:inputs.keys.drop(2).to_h{|p|[p,File.read(File.join(root,p))]},limits:'These are saved Ghidra decompilations, not fresh disassembly or hardware traces. Entry to initialization, actual handler number, queue consumption, timing units and reset coupling are not established. Equal worker state can still skip processing.'})
