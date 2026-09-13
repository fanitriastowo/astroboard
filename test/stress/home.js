import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

// Staged ramp avoids the instant 200-VU thundering herd that exhausted
// file descriptors (`:emfile`) in dev. Phases: warm-up -> steady state ->
// stress peak -> ramp-down. Total 90s + 30s graceful stop.
export const options = {
  stages: [
    { duration: '20s', target: 20 },
    { duration: '30s', target: 50 },
    { duration: '30s', target: 200 },
    { duration: '10s', target: 0 },
  ],
  gracefulStop: '30s',
  // Reuse keep-alive connections: fewer sockets per VU, less fd churn
  // on the ThousandIsland acceptor. Set K6_NO_CONNECTION_REUSE=1 to
  // test worst-case handshake behavior instead.
  noConnectionReuse: __ENV.K6_NO_CONNECTION_REUSE === '1',
  userAgent: 'k6-astroboard-stress/1.0',
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    // Baseline gate for dev + SQLite. Tighten to p(95)<500 once testing
    // a prod release with raised ulimit (see plan notes on `:emfile`).
    http_req_duration: ['p(95)<1000'],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/`, { tags: { name: 'home' }, timeout: '10s' });
  check(res, {
    'status is 200 or 302': (r) => r.status === 200 || r.status === 302,
  });
  // Jittered think time so VUs don't re-hit in lockstep after ramp-up.
  sleep(0.8 + Math.random() * 0.4);
}
