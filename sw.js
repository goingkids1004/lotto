// 두꺼비 로또 앱 서비스 워커
// 항상 인터넷에서 최신 파일을 먼저 받고, 연결이 안 될 때만 저장해 둔 파일을 보여준다.
// (매주 갱신되는 당첨번호가 옛날 것으로 남지 않도록 network-first)
const CACHE = 'lotto-v2';
const CORE = [
  './', './index.html', './predict.html', './saju.html', './check.html', './vendor/jsQR.js',
  './data/lotto.js', './data/stores.js', './logo.png', './icon-192.png', './manifest.webmanifest',
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(req, { cache: 'no-cache' })
      .then(res => {
        if (res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req, { ignoreSearch: true })
        .then(hit => hit || (req.mode === 'navigate' ? caches.match('./predict.html') : undefined)))
  );
});
