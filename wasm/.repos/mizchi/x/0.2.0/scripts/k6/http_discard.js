import http from 'k6/http';
import { check } from 'k6';

const baseUrl = __ENV.BASE_URL || 'http://127.0.0.1:18080';
const bodySize = Number(__ENV.BODY_SIZE || 16384);
const payload = 'x'.repeat(bodySize);

export const options = {
  scenarios: {
    discard: {
      executor: 'constant-vus',
      vus: Number(__ENV.VUS || 128),
      duration: __ENV.DURATION || '20s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.001'],
  },
};

export default function () {
  const res = http.post(`${baseUrl}/discard`, payload, {
    headers: { 'Content-Type': 'text/plain' },
  });
  check(res, { 'status is 204': (r) => r.status === 204 });
}
