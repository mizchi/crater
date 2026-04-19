import http from 'k6/http';
import { check } from 'k6';

const baseUrl = __ENV.BASE_URL || 'http://127.0.0.1:18080';

export const options = {
  scenarios: {
    ping: {
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
  const res = http.get(`${baseUrl}/ping`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
