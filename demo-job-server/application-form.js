'use strict';
const $ = id => document.getElementById(id);
const storeKey = 'fuse.demo.form.v1';
let payload = null, busy = false;
const pause = ms => new Promise(resolve => setTimeout(resolve, matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : ms));
async function json(url, options) {
  const response = await fetch(url, {...options, signal: AbortSignal.timeout(15000)});
  const body = await response.json();
  if (!response.ok) throw new Error(body.error || 'The demo inbox is unavailable.');
  return body;
}
function showValues() {
  for (const key of ['candidateName','email','resume','coverLetter']) $(key).value = payload[key];
  for (const id of ['step1','step2','step3']) $(id).classList.add('done');
  $('submit').disabled = false;
  $('fill').disabled = true;
}
try {
  const saved = sessionStorage.getItem(storeKey);
  if (saved) { payload = JSON.parse(saved); showValues(); $('status').textContent = 'Saved application restored. Submit again to retrieve the same receipt safely.'; }
} catch { $('error').textContent = 'Browser storage unavailable. Keep this page open until delivery is confirmed.'; }
$('fill').addEventListener('click', async () => {
  if (busy || payload) return;
  busy = true; $('fill').disabled = true; $('error').textContent = '';
  try {
    const draft = await json('/api/demo/prepared-application');
    payload = {...draft, applicationID: crypto.randomUUID()};
    sessionStorage.setItem(storeKey, JSON.stringify(payload));
    const fields = [['candidateName','nameField','Adding contact details…','step1'],['email','emailField','Adding email address…','step1'],['resume','resumeField','Adding the résumé tailored by FUSE…','step2'],['coverLetter','letterField','Adding your tailored cover letter…','step3']];
    for (const [key,field,message,step] of fields) {
      $('status').textContent = message; $(field).classList.add('active');
      $(field).scrollIntoView({behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant':'smooth', block:'center'});
      await pause(650); $(key).value = payload[key]; await pause(1000);
      $(field).classList.remove('active'); $(step).classList.add('done');
    }
    $('status').textContent = 'All four fields filled. Ready to submit to Bright Labs.';
    $('submit').disabled = false; $('submit').focus();
  } catch (error) { $('error').textContent = error.message; payload = null; $('fill').disabled = false; }
  finally { busy = false; }
});
$('application').addEventListener('submit', async event => {
  event.preventDefault(); if (busy || !payload) return;
  busy = true; $('submit').disabled = true; $('error').textContent = '';
  $('status').textContent = 'Submitting to the local employer…';
  try {
    const receipt = await json('/api/demo/applications', {method:'POST', headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
    $('status').textContent = 'Checking the employer’s saved receipt…';
    const verified = await json('/api/demo/applications/' + encodeURIComponent(payload.applicationID));
    if (verified.applicationID.toLowerCase() !== payload.applicationID.toLowerCase() || verified.receiptID !== receipt.receiptID || verified.status !== 'received' || verified.jobID !== payload.jobID || verified.candidateName !== payload.candidateName) throw new Error('Receipt could not be verified. Retry with the same application.');
    $('step4').classList.add('done'); $('status').textContent = 'Delivered. Receipt independently verified.';
    $('receipt').textContent = verified.receiptID; $('received').textContent = new Date(verified.receivedAt).toLocaleString();
    $('success').hidden = false; $('submit').textContent = 'Application received ✓';
    $('success').focus(); $('success').scrollIntoView({behavior:'smooth',block:'center'});
  } catch (error) { $('error').textContent = error.message + ' Retry uses the same application ID to prevent duplicates.'; $('submit').disabled = false; $('submit').textContent = 'Retry delivery / check receipt'; }
  finally { busy = false; }
});
