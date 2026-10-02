#!/usr/bin/env ruby
require 'json';require 'digest';require 'fileutils'
b=File.binread('ghidra/inputs/psp-p3/t28-payload.bin');sha=Digest::SHA256.hexdigest(b)
raise 'Unreviewed firmware' unless sha=='edae7f4dcdbeab4267b5201218ea7c1be56e8d6cfb9bf1909fba893eb13042c9'
base=0xe00100
checks=[]
read=lambda{|va,n|x=b.byteslice(va-base,n);raise 'Out of bounds' unless x&&x.size==n;x}
half=lambda{|va|read.call(va,2).unpack1('v')}
exact=lambda{|va,hex,meaning|actual=read.call(va,hex.size/2).unpack1('H*');raise "Changed #{va.to_s(16)}" unless actual==hex;checks<<{va:va,bytes:actual,meaning:meaning}}
bl=lambda do |va,target|
 h1,h2=read.call(va,4).unpack('v2');raise 'Not Thumb BL' unless (h1&0xf800)==0xf000&&(h2&0xd000)==0xd000
 s=(h1>>10)&1;j1=(h2>>13)&1;j2=(h2>>11)&1;i1=(~(j1^s))&1;i2=(~(j2^s))&1
 imm=(s<<24)|(i1<<23)|(i2<<22)|((h1&0x3ff)<<12)|((h2&0x7ff)<<1);imm-=1<<25 if (imm&(1<<24))!=0
 actual=va+4+imm;raise 'BL target mismatch' unless actual==target
 checks<<{va:va,bytes:read.call(va,4).unpack1('H*'),meaning:'BL',target:actual}
end
branch=lambda do |va,target,condition|
 h=half.call(va)
 if condition=='B'
  raise 'Not 16-bit B' unless (h&0xf800)==0xe000;imm=h&0x7ff;imm-=0x800 if imm>=0x400;actual=va+4+2*imm
 elsif condition=='BNE'
  raise 'Not BNE' unless (h&0xff00)==0xd100;imm=h&0xff;imm-=0x100 if imm>=0x80;actual=va+4+2*imm
 else
  raise 'Not CBZ/CBNZ' unless (h&0xf500)==0xb100
  nonzero=(h&0x800)!=0;raise 'Wrong CB condition' unless nonzero==(condition=='CBNZ')
  imm=(((h>>9)&1)<<6)|(((h>>3)&0x1f)<<1);actual=va+4+imm
 end
 raise "Branch target mismatch #{va.to_s(16)} #{actual.to_s(16)}" unless actual==target
 checks<<{va:va,bytes:read.call(va,2).unpack1('H*'),meaning:condition,target:actual,register:(condition.start_with?('CB') ? h&7 : nil)}
end
bl.call(0xe0a10c,0xe0a130)
branch.call(0xe0a110,0xe0a126,'CBZ')
branch.call(0xe0a116,0xe0a126,'CBZ')
branch.call(0xe0a11a,0xe0a126,'CBNZ')
exact.call(0xe0a11e,'042d','CMP r5,4; wrapper bounds retry count')
bl.call(0xe16dfa,0xe0a0e8)
exact.call(0xe16dfe,'0400','MOVS r4,r0')
branch.call(0xe16e00,0xe16e4e,'BNE')
branch.call(0xe16e4e,0xe16f82,'B')
exact.call(0xe16f86,'5fdf','SVC 5f cleanup')
exact.call(0xe16f9a,'2046','MOV r0,r4 returns retained image status')
bl.call(0xe0db9c,0xe16d88)
exact.call(0xe0dba0,'0700','MOVS r7,r0')
branch.call(0xe0dba2,0xe0dc02,'BNE')
branch.call(0xe0dc22,0xe0dc5c,'CBNZ')
bl.call(0xe0dc56,0xe0fb18)
exact.call(0xe0dc5c,'3846','MOV r0,r7 returns retained ordinary-loader status')
branch.call(0xe0fc14,0xe0fc1e,'BNE')
exact.call(0xe0fc1c,'7cdf','SVC 7c conditional management write')
bl.call(0xe0fc1e,0xe170e0)
exact.call(0xe170e2,'0024','MOVS r4,0; late helper fixes its returned status to zero')
exact.call(0xe170e4,'0248','LDR r0, literal at e170f0')
exact.call(0xe170e6,'0121','MOVS r1,1')
exact.call(0xe170e8,'0422','MOVS r2,4')
exact.call(0xe170ea,'7cdf','SVC 7c late filter-target write')
exact.call(0xe170ec,'2046','MOV r0,r4 discards SVC status')
raise 'Wrong late target' unless read.call(0xe170f0,4).unpack1('V')==0x1f8a4
raise 'Wrong management target' unless read.call(0xe0fd78,4).unpack1('V')==0x0900c004
# Full saved-function text is independently refreshed from a read-only Ghidra export.
asm=File.read('exports/vcn-priority-audit/load-reset-functions.asm')
# Fixture calculations represent only the recovered branch contract, not CPU execution.
['00e0fc0c  ldr r0,[sp,#0x14]','00e0fc0e  sub.w r1,r0,#0xff00','00e0fc12  subs r1,#0xff'].each do |line|
 raise "Missing predicate evidence: #{line}" unless asm.include?(line)
end
scenarios=[
 {name:'final_missing_id',image_status:0xffff0008,context:0xffff},
 {name:'final_usage_mismatch',image_status:0x80000205,context:0xffff},
 {name:'accepted_host_context',image_status:0,context:0xffff},
 {name:'accepted_index_context',image_status:0,context:1},
 {name:'accepted_all_ones_context',image_status:0,context:0xffffffff}
].map do |x|
 reaches=x[:image_status]==0 # assumes all other prerequisite and downstream pre-completion checks succeed
 x.merge(completion_reached:reaches,management_write_requested:reaches&&x[:context]==0xffff,late_filter_write_requested:reaches,
         physical_reset_released:nil,qualification:'Bounded branch-contract fixture, not execution; acceptance alone does not guarantee other checks pass')
end
report={date:'2026-10-01',firmware_sha256:sha,mapping:'t28 VA = payload offset + e00100',raw_instruction_checks:checks,scenarios:scenarios,
 conclusion:'A final nonzero image-processing status takes cleanup and skips ordinary type-13 completion, including its conditional 0900c004 write and late 1f8a4 write.',
 header_retry_caveat:'Wrapper e0a0e8 may try up to four 0x100-spaced headers when byte+7f is nonzero and word+18 is zero; a missing ID at one attempted header is not necessarily the final image-processing result.',
 limits:['No field-name or physical reset validation','Only recovered ordinary LOAD_IP_FW route; restore/replay and other writers remain separate','Normal stack-protector return and firmware ABI assumed','Other prerequisites/checks can prevent completion even with image status zero','Known SVC store instruction does not prove store acceptance; late helper discards its status']}
FileUtils.mkdir_p('exports/vcn-priority-audit');File.write('exports/vcn-priority-audit/load-reset-gate.json',JSON.pretty_generate(report)+"\n")
puts "Verified #{checks.size} raw instruction/branch checks and #{scenarios.size} scoped branch fixtures."
