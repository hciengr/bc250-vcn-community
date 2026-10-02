'use strict';
(() => {
  const dialog=document.createElement('dialog');
  dialog.className='terminal-dialog';dialog.setAttribute('aria-labelledby','terminal-title');
  dialog.innerHTML='<div class="terminal-bar"><span class="terminal-lights" aria-hidden="true">● ● ●</span><h2 id="terminal-title">Research text</h2><button type="button" class="terminal-close" aria-label="Close text panel">×</button></div><p class="terminal-command" aria-hidden="true">research@bc250:~$ cat evidence</p><textarea class="terminal-output" readonly spellcheck="false" aria-label="Copyable research text"></textarea><div class="terminal-actions"><span role="status" class="terminal-status"></span><button type="button" class="terminal-select">Select all</button><button type="button" class="primary terminal-copy">Copy text</button></div>';
  document.body.append(dialog);
  const output=dialog.querySelector('textarea'),status=dialog.querySelector('.terminal-status');
  function show(title,text){dialog.querySelector('h2').textContent=title;output.value=text;status.textContent='';if(!dialog.open)dialog.showModal();output.scrollTop=0;}
  dialog.querySelector('.terminal-close').onclick=()=>dialog.close();
  dialog.querySelector('.terminal-select').onclick=()=>{output.focus();output.select();};
  dialog.querySelector('.terminal-copy').onclick=async()=>{try{await navigator.clipboard.writeText(output.value);status.textContent='Copied.';}catch{output.focus();output.select();status.textContent='Text selected. Press Ctrl+C or Command+C.';}};
  window.TerminalView={show};
  document.addEventListener('click',async event=>{
    const link=event.target.closest('a[href]');if(!link||event.defaultPrevented)return;
    const url=new URL(link.href,location.href);
    if(/\.(?:bin|rom|zip|gz|deb|pdf)$/i.test(url.pathname)){
      event.preventDefault();show('Artifact reference',`Artifact: ${url.href}\n\nBinary artifact. No file is downloaded by this view. Consult its source record, input hash and acquisition instructions before using it.`);return;
    }
    if(url.origin!==location.origin||! /\.(?:md|json|txt|csv|tsv|rb|pl|py|java|c|h|sh|asm|log|pem|patch|cfg|xml|ini)$/i.test(url.pathname))return;
    event.preventDefault();show(link.textContent.trim()||'Source text','Loading source text…');
    try{const response=await fetch(url.href);if(!response.ok)throw Error(`HTTP ${response.status}`);show(link.textContent.trim()||'Source text',await response.text());}
    catch(error){show('Source unavailable',`Source: ${url.href}\n\n${error.message}\nUse the local HTTP preview or hosted site to read this source. No substitute evidence was generated.`);}
  });
})();
