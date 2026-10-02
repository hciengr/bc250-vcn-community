#!/usr/bin/env ruby
# Stored-policy coverage audit. No execution, address-space translation or live grants inferred.
require 'json'
require 'digest'
require 'fileutils'
module VcnPolicyAudit
  module_function
  def u32(b,o)
    raise "Truncated word at #{o}" unless o>=0&&o+4<=b.bytesize
    b.byteslice(o,4).unpack1('V')
  end
  def hx(n);format('0x%x',n);end
  def fletcher(bytes)
    c0=c1=0xffff
    bytes.unpack('v*').each_with_index do |v,i|
      c0+=v;c1+=c0
      if i%360==0
        c0=(c0&0xffff)+(c0>>16);c1=(c1&0xffff)+(c1>>16)
      end
    end
    2.times {c0=(c0&0xffff)+(c0>>16);c1=(c1&0xffff)+(c1>>16)}
    (c1<<16)|c0
  end
  def directory(b,offset)
    raise 'Bad directory magic' unless %w[$PSP $PL2].include?(b.byteslice(offset,4))
    count=u32(b,offset+8);raise 'Bad directory size' unless count.between?(1,256)&&offset+16+16*count<=b.size
    raw=b.byteslice(offset,16+16*count)
    raise 'Directory checksum mismatch' unless fletcher(raw.byteslice(8..))==u32(b,offset+4)
    rows=count.times.map do |i|
      id,size,encoded=raw.byteslice(16+i*16,16).unpack('V2Q<')
      mode=encoded>>62
      address=case mode
      when 0 then encoded&0xffffff # pinned BC250 absolute SPI address in 16MiB ROM
      when 2 then offset+(encoded&0x3fffffffffffffff) # directory-relative in pinned capsule
      else nil
      end
      {index:i,identity:id,size:size,encoded_address:hx(encoded),address_mode:mode,file_offset:address}
    end
    {offset:offset,checksum:hx(u32(b,offset+4)),checksum_verified:true,count:count,entries:rows}
  end
  def parse(b)
    raise 'Missing outer magic' unless b.byteslice(0x10,4)=='$PS1'
    length=u32(b,0x14);finish=0x100+length
    raise 'Outer body/file mismatch' unless b.size==finish+0x100
    count=u32(b,0x100);raise 'Invalid section count' unless count.between?(1,64)
    cursor=0x140
    sections=count.times.map do
      raise 'Section exceeds body' unless cursor+8<=finish
      id,n=b.byteslice(cursor,8).unpack('V2')
      raise 'Invalid section/bounds' unless id.between?(0x200,0x2ff)&&n<=0x4000&&cursor+8+n*8<=finish
      offset=cursor
      pairs=n.times.map {|i|a,v=b.byteslice(cursor+8+8*i,8).unpack('V2');{offset:cursor+8+8*i,target:a,value:v}}
      cursor+=8+8*n
      {id:id,offset:offset,count:n,pairs:pairs}
    end
    padding=b.byteslice(cursor,finish-cursor)
    raise 'Unparsed nonzero body content' unless padding.bytes.all?(&:zero?)
    {body_end:finish,parsed_end:cursor,zero_padding_bytes:padding.size,sections:sections}
  end
  def frame(target)
    target.between?(0x09000000,0x09ffffff) ? ((target-0x09000000)>>12) : nil
  end
  def analyze(parsed)
    pairs=parsed[:sections].flat_map {|s|s[:pairs].map{|p|p.merge(section:s[:id])}}
    crows=pairs.select{|p|p[:target].between?(0x0900c000,0x0900cfff)}
    vals=pairs.select{|p|p[:value]>=0x1e000&&p[:value]<0x23000}
    direct=pairs.select{|p|p[:target]>=0x1e000&&p[:target]<0x23000}
    # Empirical descriptor layout from SD section 201: starts 934+24*k, end +4.
    # Candidate geometry, not a hardware schema or activation model. Never join sections.
    candidates=[]
    parsed[:sections].each do |s|
      grouped=s[:pairs].group_by{|p|frame(p[:target])}.reject{|key,_|key.nil?}
      grouped.each do |f,rows|
        8.times do |slot|
          start_target=0x09000000+(f<<12)+0x934+0x24*slot
          starts=rows.select{|p|p[:target]==start_target};ends=rows.select{|p|p[:target]==start_target+4}
          starts.product(ends).each do |a,z|
            next unless a[:value]<=z[:value]
            # Inclusive range intersection catches windows spanning the whole VCN range.
            overlap=a[:value]<0x23000&&z[:value]>=0x1e000
            candidates << {section:s[:id],frame_index:f,slot:slot,start:a[:value],end:z[:value],overlaps_vcn_numeric_range:overlap,start_row_offset:a[:offset],end_row_offset:z[:offset]}
          end
        end
      end
    end
    {pair_count:pairs.size,frame_c_rows:crows,vcn_numeric_value_rows:vals,vcn_direct_target_rows:direct,
     section201_frame_counts:pairs.select{|p|p[:section]==0x201&&frame(p[:target])}.group_by{|p|frame(p[:target])}.transform_values(&:size),
     candidate_descriptors:candidates,candidate_vcn_overlaps:candidates.select{|r|r[:overlaps_vcn_numeric_range]}}
  end
  def main
    inputs=[
      {name:'BC250_P3',path:'firmware/stock/BC250_3.00.ROM',sha:'07595ca3aecf8a4caa28a397b5298f3946a1b769f87b16f67adc369c3f69045c',dirs:[0x8e0000]},
      {name:'SteamDeck_F7A0116',path:'analysis/steamdeck-comparison/F7A0116_sign.fd',sha:'ef5d7c8bc73bed9b9a0be51771b629660b6aeca300bf7734c6c36a785c9b4296',dirs:[0x168c70,0x968c70]}
    ]
    objects=[];directories=[]
    inputs.each do |input|
      bytes=File.binread(input[:path]);raise 'Input changed' unless Digest::SHA256.hexdigest(bytes)==input[:sha]
      input[:dirs].each do |off|
        dir=directory(bytes,off);directories<<{platform:input[:name],source:input[:path],directory:dir}
        dir[:entries].select{|e|[0x24,0x45].include?(e[:identity]&0xff)}.each do |e|
          at=e[:file_offset];raise 'Unmapped/truncated policy' unless at&&at>=0&&at+e[:size]<=bytes.size
          blob=bytes.byteslice(at,e[:size]);parsed=parse(blob)
          if input[:name]=='BC250_P3'
            name=(e[:identity]&0xff)==0x24 ? 'SEC_GASKET~0x24_B.51.0.16' : 'TOS_SECURITY_POLICY~0x45_B.51.1.16'
            raise 'Extracted policy differs from ROM' unless File.binread("analysis/psp_extract/BC250_3.00_unique/#{name}")==blob
          end
          objects << {platform:input[:name],type:e[:identity]&0xff,source:input[:path],source_sha256:input[:sha],directory_offset:off,object_offset:at,object_bytes:blob.size,object_sha256:Digest::SHA256.hexdigest(blob),parse:parsed,coverage:analyze(parsed)}
        end
      end
    end
    bc=objects.select{|o|o[:platform]=='BC250_P3'}
    raise 'Expected t24/t45' unless bc.size==2
    raise 'Unexpected BC frame-C rows' unless bc.all?{|o|o[:coverage][:frame_c_rows].empty?}
    raise 'Unexpected BC numeric VCN values' unless bc.all?{|o|o[:coverage][:vcn_numeric_value_rows].empty?}
    raise 'Unexpected BC candidate spans' unless bc.all?{|o|o[:coverage][:candidate_vcn_overlaps].empty?}
    preloads=bc.flat_map{|o|o[:coverage][:vcn_direct_target_rows]}.map{|r|[r[:target],r[:value]]}
    raise 'Preloads changed' unless preloads==[[0x1f8a4,0xb],[0x1f820,0x185103]]
    sd=objects.select{|o|o[:platform]=='SteamDeck_F7A0116'&&o[:type]==0x24}
    raise 'Duplicate objects disagree' unless sd.map{|o|o[:object_sha256]}.uniq.size==1
    sd.each do |o|
      ranges=o[:coverage][:candidate_descriptors].select{|r|r[:section]==0x201&&r[:frame_index]==0xc}.map{|r|[r[:start],r[:end]]}.sort
      raise 'SD window geometry changed' unless ranges==[[0x1f82c,0x1f833],[0x20470,0x2086f],[0x219d0,0x21acf]]
    end
    report={date:'2026-10-01',method:'Hash-pinned ROM/capsule, checked PSP-directory Fletcher checksums, bounded complete policy parsing and independent coverage scans',
      vcn_numeric_interval:{start:0x1e000,end_exclusive:0x23000},inputs:inputs,directories:directories,objects:objects,
      proven:['Stored P3 t24 and t45 contain no explicit target in management frame 0900c000..0900cfff','Neither stored policy has a value in numeric VCN interval','Empirical descriptor spans from any frame do not overlap the numeric interval in stored BC policies','Only two direct VCN-range target rows: 1f8a4=0b,1f820=185103','Saved SD t24 supplies the reported three frame-C descriptor ranges'],
      limitations:['Stored table inventory, not runtime activation or absence of all possible dynamic grants','Descriptor stride/offset interpretation is empirical SD evidence; field semantics/enable controls not independently established','Numeric range overlap is not universal cross-IP identity; some other SD frames have similarly numbered values','RN/CZN reference not included; eight-window claim remains untested','RSMU cold-reset field identity, hardware reset state and PSP filter bypass remain unvalidated','Zero rows do not establish read-only state, fuses, total later-writer absence or live bus behavior']}
    FileUtils.mkdir_p('exports/vcn-priority-audit');File.write('exports/vcn-priority-audit/policy-coverage.json',JSON.pretty_generate(report)+"\n")
    objects.each{|o|c=o[:coverage];puts "#{o[:platform]} t#{o[:type].to_s(16)} #{o[:directory_offset].to_s(16)}: #{c[:pair_count]} pairs; frame-C=#{c[:frame_c_rows].size}, VCN values=#{c[:vcn_numeric_value_rows].size}, direct targets=#{c[:vcn_direct_target_rows].size}"}
  end
end
VcnPolicyAudit.main if $PROGRAM_NAME==__FILE__
