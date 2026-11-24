# 🇨🇳 상하이 여행 후보 고르기

두 사람이 각자 후보마다 **💖 꼭 / 🙂 괜찮아 / 🙅 패스**를 고르고, 언제든 바꿀 수 있는 페이지예요.
체크는 Supabase에 저장되고 실시간으로 동기화돼서, 상대방이 고른 것도 바로 보여요.

- 화면: GitHub Pages (정적 HTML 파일 1개)
- 저장: Supabase (무료 플랜, 별도 백엔드 코드 없음)

```
shanghai-picks/
├─ index.html          ← 페이지 전체 (설정 + 후보 목록 + 동작 코드)
├─ supabase-setup.sql  ← Supabase에서 한 번 실행할 SQL
└─ README.md
```

---

## 1. Supabase 설정 (약 5분)

1. https://supabase.com 에 가입하고 **New project**를 만들어요.
   - Region은 `Northeast Asia (Seoul)`이나 `Tokyo`를 추천해요.
2. 왼쪽 메뉴 **SQL Editor**에서 `supabase-setup.sql` 내용을 붙여넣고 **Run**을 눌러요.
3. **Project Settings → API**(또는 **API Keys**)에서 두 가지를 복사해요.
   - **Project URL** (예: `https://abcdxyz.supabase.co`)
   - **anon public** 키 또는 **Publishable** 키 (`service_role`이나 secret 키는 절대 넣지 마세요)

## 2. index.html 설정

파일 위쪽 `CONFIG`만 수정하면 돼요.

```js
const CONFIG = {
  SUPABASE_URL: "https://abcdxyz.supabase.co",
  SUPABASE_KEY: "복사한 anon 또는 publishable 키",
  PEOPLE: ["내이름", "친구이름"],
};
```

> 설정하지 않고 열면 **로컬 모드**로 동작해요. 체크가 그 기기에만 저장되니 화면 미리보기용으로 쓰세요.

후보는 모두 Supabase `places` 테이블에 저장되고, 화면에서 추가·수정·삭제해요. 그래서 파일을 다시 배포하지 않아도 두 사람 모두에게 바로 반영돼요.
기본 후보 29곳은 `supabase-setup.sql`을 실행하면 들어가요. `index.html`의 `SEED_PLACES`는 로컬 모드에서만 초기값으로 써요.

## 3. GitHub Pages 배포

```bash
git init
git add .
git commit -m "상하이 후보 페이지"
git branch -M main
git remote add origin https://github.com/<아이디>/shanghai-picks.git
git push -u origin main
```

GitHub 저장소 **Settings → Pages → Build and deployment**에서
Source를 `Deploy from a branch`, Branch를 `main` / `/ (root)`로 지정하고 저장해요.
1~2분 뒤 `https://<아이디>.github.io/shanghai-picks/` 링크가 생겨요. 이 링크를 친구에게 보내면 돼요.

## 사용 방법

- 처음 들어가면 **"누구세요?"**에서 이름을 골라요. 이 기기에 기억되고, 오른쪽 위 버튼으로 바꿀 수 있어요.
- 같은 버튼을 한 번 더 누르면 선택이 해제돼요.
- **추가:** 오른쪽 아래 **＋ 후보 추가** 버튼을 눌러요.
- **수정:** 카드의 **✏️ 수정**을 누르면 이름, 카테고리, 설명, 사진 등을 바꿀 수 있어요. 기본 후보도 수정할 수 있어요.
- **삭제:** 수정 창 아래 **🗑 이 후보 삭제**를 누르면 후보와 두 사람의 선택 기록, 사진이 함께 지워져요.
- **사진:** 추가 또는 수정 창에서 넣어요. 장소당 1장이고, 올리기 전에 자동으로 크기를 줄여서 한 장에 보통 수백 KB 정도만 차지해요.
- **🤝 결과 보기** 탭에서 "둘 다 꼭 / 유력 / 의견 갈림"으로 묶어서 볼 수 있어요.
- **📋 결과 복사** 버튼으로 텍스트를 복사해 카톡에 붙여넣을 수 있어요.

## 문제가 생기면

- **"권한이 없어요" / "테이블이 없어요"가 뜰 때:** `supabase-setup.sql` 전체를 SQL Editor에서 다시 실행해 주세요. 2026년 5월 30일 이후 만든 Supabase 프로젝트는 테이블에 `GRANT`로 직접 권한을 줘야 API로 접근할 수 있어요. 최신 SQL에는 이 부분이 들어 있어요.
- 그 밖의 오류는 안내 문구에 Supabase 오류 메시지가 그대로 나와요. 브라우저 개발자 도구 Console에도 자세한 내용이 찍혀요.
- 기본 후보를 화면에서 삭제한 뒤 SQL을 다시 실행하면 그 후보가 다시 생겨요. 수정한 내용은 덮어쓰지 않아요.

## 알아두면 좋은 점

- **보안:** anon 키는 원래 브라우저에 노출되는 용도의 키예요. 다만 지금 정책은 링크와 키를 아는 사람이면 누구나 체크를 수정할 수 있게 열어 둔 상태예요. 둘이 쓰는 여행 페이지라면 충분하고, 링크만 공유 범위를 조심하면 돼요.
- **무료 플랜 일시정지:** Supabase 무료 프로젝트는 일정 기간(약 1주) 아무도 쓰지 않으면 일시정지될 수 있어요. 대시보드에서 **Restore**를 누르면 데이터 그대로 다시 켜져요.
- **중국 현지에서 볼 때:** 중국 현지 유심이나 와이파이로는 GitHub·Google 지도 같은 해외 서비스 접속이 막힐 수 있어요. 여행 중에도 보실 거라면 한국 로밍이나 해외 eSIM을 쓰시거나, 출발 전에 결과를 복사해 두세요.
