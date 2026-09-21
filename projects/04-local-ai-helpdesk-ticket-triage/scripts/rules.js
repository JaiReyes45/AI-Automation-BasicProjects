const crypto = require('crypto');
const categories = ['account','billing','technical','security','feature_request','general','unknown'];
const queues = ['security_response','technical_support','account_support','billing_support','product_feedback','general_support','manual_review'];
const priorities = ['P1','P2','P3','P4'];
const sentiments = ['positive','neutral','negative','angry','abusive','unknown'];
const concerns = ['none','pii_or_secret','account_takeover','security_incident','self_harm_or_threat','unknown'];
const required = ['category','priority','summary','sentiment','assigned_queue','confidence','needs_human_review','reason','safety_or_security_concern'];
const hash = value => crypto.createHash('sha256').update(value).digest('hex');

function validateTicket(input) {
  if (!input || typeof input !== 'object') throw Error('invalid_payload');
  const email = String(input.email || '').trim().toLowerCase();
  const subject = String(input.subject || '').trim();
  const description = String(input.description || '').trim();
  if (!/^\S+@\S+\.\S+$/.test(email)) throw Error('invalid_email');
  if (!subject) throw Error('empty_subject');
  if (!description) throw Error('empty_description');
  if (subject.length > 200 || description.length > 10000) throw Error('content_too_long');
  return { email, subject, description };
}

function validateClassification(output) {
  if (!output || typeof output !== 'object' || Array.isArray(output)) throw Error('invalid_classification');
  for (const key of required) if (!(key in output)) throw Error('missing_' + key);
  if (!categories.includes(output.category) || !priorities.includes(output.priority) ||
      !queues.includes(output.assigned_queue) || !sentiments.includes(output.sentiment) ||
      !concerns.includes(output.safety_or_security_concern)) throw Error('invalid_enum');
  if (typeof output.confidence !== 'number' || !Number.isFinite(output.confidence) ||
      output.confidence < 0 || output.confidence > 1) throw Error('invalid_confidence');
  if (typeof output.needs_human_review !== 'boolean') throw Error('invalid_review_flag');
  if (!String(output.summary).trim() || String(output.summary).length > 280 ||
      !String(output.reason).trim() || String(output.reason).length > 500) throw Error('invalid_text');
  return output;
}

function idempotency(input) {
  const t = validateTicket(input);
  return hash([t.email,t.subject,t.description,String(input.idempotencyKey || '')].join('|'));
}

function route(classification, ticketText) {
  const c = validateClassification(classification);
  const text = String(ticketText || '').toLowerCase();
  const security = c.category === 'security' || /account takeover|compromis|security incident|credential/.test(text) || c.safety_or_security_concern === 'account_takeover' || c.safety_or_security_concern === 'security_incident';
  const outage = /outage|service down|all users|production down/.test(text);
  const review = security || outage || c.confidence < 0.80 || c.needs_human_review || c.category === 'unknown' || c.safety_or_security_concern !== 'none';
  let priority = security ? 'P1' : outage ? 'P2' : c.priority;
  if ((c.category === 'account' || c.category === 'technical') && priority === 'P4') priority = 'P3';
  return { ...c, priority, assigned_queue: security ? 'security_response' : review ? 'manual_review' : c.assigned_queue, needs_human_review: review };
}

function retryDelaySeconds(attempt) {
  if (!Number.isInteger(attempt) || attempt < 1 || attempt > 3) throw Error('invalid_attempt');
  return [30, 120, 600][attempt - 1];
}

function addBusinessMinutes(start, minutes) {
  let at = new Date(start);
  if (Number.isNaN(at.getTime())) throw Error('invalid_received_at');
  let left = minutes;
  while (left > 0) {
    const day = at.getUTCDay();
    const hour = at.getUTCHours();
    if (day === 6) { at.setUTCDate(at.getUTCDate() + 2); at.setUTCHours(1,0,0,0); continue; }
    if (day === 0) { at.setUTCDate(at.getUTCDate() + 1); at.setUTCHours(1,0,0,0); continue; }
    if (hour < 1) { at.setUTCHours(1,0,0,0); continue; }
    if (hour >= 9) { at.setUTCDate(at.getUTCDate() + 1); at.setUTCHours(1,0,0,0); continue; }
    const available = (9 - hour) * 60 - at.getUTCMinutes();
    const used = Math.min(left, available);
    at = new Date(at.getTime() + used * 60000);
    left -= used;
  }
  return at;
}

function slaDeadline(priority, receivedAt) {
  const minutes = { P1: 240, P2: 480, P3: 960, P4: 2400 }[priority];
  if (!minutes) throw Error('invalid_priority');
  const received = new Date(receivedAt);
  if (Number.isNaN(received.getTime())) throw Error('invalid_received_at');
  if (priority === 'P1') return new Date(received.getTime() + minutes * 60000);
  return addBusinessMinutes(receivedAt, minutes);
}

module.exports = { validateTicket, validateClassification, idempotency, route, retryDelaySeconds, slaDeadline };
