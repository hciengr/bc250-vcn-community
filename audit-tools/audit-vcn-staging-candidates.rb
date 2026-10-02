#!/usr/bin/env ruby
require 'json';require 'digest';require 'fileutils'
# Bounded candidate scan, not instruction reachability or a directory loader reconstruction.
targets=[0x784000,0x784100]
paths=Dir.glob('analysis/psp_extract/BC250_3.00_unique/*').select{|p|File.file?(p)}+
 Dir.glob('exports/abl0-p3/abl[0-4]-payload.bin')+%w[ghidra/inputs/psp-p3/t02-payload.bin ghidra/inputs/psp-p3/t28-payload.bin]
control='exports/rom-source-hunt/extracted/4800s_psp/MX25L12872F_AMD_4800S.bin_unique_extracted/PSP_FW_BOOT_LOADER~0x1_0.2C.0.6'
paths<<control
rows=paths.map do |path|
 b=File.binread(path);hits=[]
 targets.each do |v|
  cursor=0
  while (cursor=b.index([v].pack('V'),cursor))
   hits<<{kind:'raw_u32',offset:cursor,value:v};cursor+=1
  end
 end
 moves=[]
 (0..b.size-4).step(2) do |o|
  h1,h2=b.byteslice(o,4).unpack('v2')
  kind=case h1&0xfbf0;when 0xf240 then 'movw';when 0xf2c0 then 'movt';else next;end
  next unless (h2&0x8000)==0
  imm=((h1&0xf)<<12)|(((h1>>10)&1)<<11)|(((h2>>12)&7)<<8)|(h2&0xff)
  rd=(h2>>8)&0xf;moves<<{kind:kind,offset:o,rd:rd,imm:imm}
 end
 moves.select{|m|m[:kind]=='movw'}.each do |lo|
  moves.select{|m|m[:kind]=='movt'&&m[:rd]==lo[:rd]&&m[:offset]>lo[:offset]&&m[:offset]<=lo[:offset]+64}.each do |hi|
   value=lo[:imm]|(hi[:imm]<<16)
   hits<<{kind:'nearby_movw_movt_candidate',offset:lo[:offset],upper_offset:hi[:offset],register:lo[:rd],value:value} if targets.include?(value)
  end
 end
 {file:path,bytes:b.size,sha256:Digest::SHA256.hexdigest(b),comparison_control:path==control,hits:hits}
end
control_row=rows.find{|r|r[:comparison_control]}
raise 'Wrong comparison control' unless control_row[:sha256]=='2bfe1d1c11a7efbd24a4febfda8c12d89815af19c687e0cfd96c5da02fa3666a'
raise 'No positive control hit' if control_row[:hits].empty?
report={date:'2026-10-01',targets:targets,sources:rows,
 method:'Exact u32 at every byte; Thumb MOVW/MOVT candidate pairs at halfword alignment up to 64 bytes apart with matching register',
 limits:['Opcode candidates can be data or unreachable code; no intervening-clobber analysis','No exclusion of ADD-based constants, aliases, transformations, encrypted code, another address space or runtime-only producers','4800S is a comparison, not the BC250 earlier loader','t28 hits describe the known consumer; they do not identify the upstream producer']}
File.write('exports/vcn-priority-audit/staging-candidates.json',JSON.pretty_generate(report)+"\n")
rows.select{|r|!r[:hits].empty?}.each{|r|puts "#{r[:file]}: #{r[:hits].map{|h|"#{h[:kind]}@#{h[:offset].to_s(16)}=#{h[:value].to_s(16)}"}.join(', ')}"}
