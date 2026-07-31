const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizePhone,
  toNetgsmOtpDest,
  parseNetgsmOtpCode,
} = require('../functions/sms_otp');

test('normalizePhone TR formats', () => {
  assert.equal(normalizePhone('05551234567'), '905551234567');
  assert.equal(normalizePhone('5551234567'), '905551234567');
  assert.equal(normalizePhone('+90 555 123 45 67'), '905551234567');
});

test('toNetgsmOtpDest strips country code', () => {
  assert.equal(toNetgsmOtpDest('905551234567'), '5551234567');
  assert.equal(toNetgsmOtpDest('05551234567'), '5551234567');
});

test('parseNetgsmOtpCode reads xml and plain codes', () => {
  assert.equal(
    parseNetgsmOtpCode('<main><code>0</code><jobID>123</jobID></main>'),
    '0',
  );
  assert.equal(parseNetgsmOtpCode('00'), '00');
});
