# 로또 6/45 당첨번호 · 예상번호 사이트

- `index.html` : 당첨번호 조회 (1회 ~ 최신 회차, 검색·연도별·번호별 출현 횟수)
- `predict.html` : 다음 회차 예상번호 생성기 + 백테스트
- `data/lotto.csv` : 전체 당첨번호 (엑셀에서 바로 열림)
- `data/lotto.js` : 웹페이지가 읽는 데이터 (자동 생성, 직접 고치지 마세요)
- `scripts/update.ps1` : 동행복권에서 새 회차를 받아 위 두 파일을 갱신
- `.github/workflows/update.yml` : 매주 토요일 22:30(한국시간) 자동 갱신 후 사이트 배포

> 개인이 만든 비공식 분석 사이트입니다. 로또는 무작위 추첨이라 예상번호가 당첨 확률을 높이지 않습니다.

---

## 1. GitHub에 올리기 (최초 1회)

1. <https://github.com> 에 가입하고 로그인합니다.
2. 오른쪽 위 **+** → **New repository**
   - Repository name: 예) `lotto`
   - **Public** 선택 (무료 계정은 Public 저장소만 Pages 사용 가능)
   - **Create repository**
3. 새 저장소 화면에서 **uploading an existing file** 링크를 누릅니다.
4. 이 폴더(`lotto-site`) **안의 내용 전부**를 선택해 브라우저로 끌어다 놓습니다.
   (`.github`, `data`, `scripts` 폴더와 `index.html`, `predict.html`, `README.md`)
   → 아래 **Commit changes** 클릭
5. 파일 목록에 `.github` 폴더가 보이는지 확인합니다.
   안 보이면: **Add file → Create new file** → 파일 이름 칸에 `.github/workflows/update.yml` 입력 →
   이 폴더의 `.github/workflows/update.yml` 내용을 복사해 붙여넣기 → **Commit changes**

## 2. GitHub Pages 켜기

1. 저장소의 **Settings → Pages**
2. **Build and deployment → Source** 를 **GitHub Actions** 로 바꿉니다.
3. 저장소의 **Actions** 탭 → 왼쪽 **로또 데이터 갱신 및 배포** → **Run workflow** → **Run workflow**
4. 1~2분 뒤 초록색 체크가 뜨면 완료. 주소는 `https://내아이디.github.io/lotto/`
   (Settings → Pages 맨 위에도 표시됩니다)

이후로는 **매주 토요일 22:30**에 새 회차를 받아 자동으로 사이트가 갱신됩니다.
토요일에 실패하면 일요일 09:00에 한 번 더 시도합니다.

## 3. 내 도메인 연결

1. 가비아·후이즈·Cloudflare 등에서 도메인을 구매합니다. 예) `mylotto.com`
2. GitHub 저장소 **Settings → Pages → Custom domain** 에 `www.mylotto.com` 입력 → **Save**
3. 도메인 구매한 곳의 **DNS 관리** 화면에서 아래 레코드를 추가합니다.

   | 타입 | 이름(호스트) | 값 |
   |---|---|---|
   | CNAME | `www` | `내아이디.github.io` |
   | A | `@` (비워두기) | `185.199.108.153` |
   | A | `@` | `185.199.109.153` |
   | A | `@` | `185.199.110.153` |
   | A | `@` | `185.199.111.153` |

   A 레코드 4개는 `www` 없이 `mylotto.com` 으로 들어와도 연결되게 해 줍니다.
4. 몇 분 ~ 최대 하루 뒤 Settings → Pages 에서 DNS 확인이 끝나면 **Enforce HTTPS** 를 체크합니다.
5. (권장) 계정 **Settings → Pages → Add a domain** 에서 도메인 소유 인증을 해 두면
   다른 사람이 내 도메인을 가로채 쓰는 것을 막을 수 있습니다.

## 4. 문제가 생겼을 때

- **Actions 에 노란 경고 "새 회차를 받아오지 못했습니다"**
  동행복권 사이트 점검이거나, 해외(GitHub 서버) 접속이 막힌 경우입니다. 사이트는 기존 데이터로 그대로 유지됩니다.
  계속 실패하면 내 PC에서 직접 갱신하세요:
  ```
  powershell -ExecutionPolicy Bypass -File scripts\update.ps1
  ```
  그다음 바뀐 `data/lotto.csv`, `data/lotto.js` 두 파일을 GitHub `data` 폴더에 다시 업로드하면 자동 배포됩니다.
- **자동 실행이 멈춤**: 저장소에 60일간 활동이 없으면 GitHub가 예약 실행을 끕니다.
  Actions 탭에서 **Enable workflow** 를 누르면 다시 켜집니다.
- **새 회차가 사이트에 안 보임**: 브라우저 캐시 때문일 수 있습니다. 10분쯤 뒤 새로고침(Ctrl+F5) 해 보세요.
