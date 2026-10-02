window.addEventListener('load',()=>{
 const results=[];
 function check(condition,message){if(!condition)throw Error(message);results.push('PASS '+message);}
 const e=id=>document.getElementById(id);
 try{
  e('start-evidence').click();check(e('evidence-dialog').open,'Evidence entry opens guided form');
  e('easy-title').value='Policy + clock & register test';e('easy-finding').value='Synthetic browser fixture, not board evidence.';
  e('easy-evidence-form').dispatchEvent(new Event('submit',{cancelable:true}));
  check(e('easy-error').textContent.includes('Add an evidence link'),'Missing artifact link or attachment promise is explained');
  e('easy-source').value='https://example.org/log?a=1&b=2';
  e('easy-evidence-form').dispatchEvent(new Event('submit',{cancelable:true}));
  check(e('handoff-dialog').open,'Evidence handoff opens before posting');
  let url=new URL(e('handoff-open').href);
  check(url.origin==='https://github.com'&&url.pathname==='/hciengr/bc250-vcn-community/issues/new','Handoff targets the correct repository');
  check(url.searchParams.get('title')==='Policy + clock & register test','Issue title preserves special characters');
  check(url.searchParams.get('body').includes('https://example.org/log?a=1&b=2'),'Evidence link survives URL encoding');
  check(url.searchParams.get('body').includes('Status: proposed')&&url.searchParams.get('body').includes('Ledger SHA-256'),'Issue keeps proposal status and snapshot identity');
  check(e('handoff-message').textContent.includes('not been shared'),'Draft is not presented as submitted');
  e('handoff-dialog').close();ContributionFlow.evidence('C32','correction');
  check(e('easy-topic').value==='C32'&&e('evidence-title').textContent.includes('counterevidence'),'Claim context and contribution type are retained');
  e('easy-title').value='Large log';e('easy-finding').value='large result '.repeat(1200);e('easy-attach').checked=true;
  e('easy-evidence-form').dispatchEvent(new Event('submit',{cancelable:true}));
  check(!e('handoff-long').hidden&&!new URL(e('handoff-open').href).searchParams.has('body'),'Large submissions use explicit copy fallback instead of oversized URLs');
  e('handoff-dialog').close();ContributionFlow.worker('T23');
  check(e('worker-dialog').open&&e('worker-task').value==='T23','Task-specific worker form opens');
  e('worker-human').value='fixture-user';e('worker-name').value='fixture-worker';
  e('worker-human').dispatchEvent(new Event('input'));e('worker-name').dispatchEvent(new Event('input'));
  check(e('worker-prompt').value.includes('fixture-user')&&e('worker-prompt').value.includes('fixture-worker'),'Copyable instructions include accountable worker identity');
  check(e('worker-prompt').value.includes(window.VCN_TASK_PACKETS[0].ledger_sha256),'Worker instructions include snapshot hash');
  e('worker-form').dispatchEvent(new Event('submit',{cancelable:true}));
  url=new URL(e('handoff-open').href);
  check(url.searchParams.get('template')==='worker-link.md'&&url.searchParams.get('body').includes('Worker ID: fixture-worker'),'Worker registration is prefilled');
  check(url.searchParams.get('body').includes('not automatic execution'),'Worker linking does not claim automatic agent execution');
  e('handoff-dialog').close();ContributionFlow.worker('T14');
  check(e('worker-mode').value==='reproduce','Review tasks default to independent reproduction');
  e('worker-human').value='fixture-user';e('worker-name').value='fixture-worker';e('worker-mode').value='investigate';
  e('worker-form').dispatchEvent(new Event('submit',{cancelable:true}));
  check(e('worker-error').textContent.includes('independent reproduction'),'Review task cannot silently become a duplicate investigation claim');
  e('worker-dialog').close();
  e('contribute').click();check(e('evidence-dialog').open,'Header entry uses the guided evidence form');e('evidence-dialog').close();
  check(document.querySelectorAll('[data-worker]').length===23,'Every task offers direct worker linking');
  document.body.dataset.browserTest='passed';
 }catch(error){results.push('FAIL '+error.message);document.body.dataset.browserTest='failed';}
 const pre=document.createElement('pre');pre.id='browser-test-results';pre.textContent=results.join('\n');document.body.appendChild(pre);
});
