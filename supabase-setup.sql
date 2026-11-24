-- 상하이 여행 후보 고르기: Supabase 설정
-- Supabase 대시보드 > SQL Editor 에 전체를 붙여넣고 Run 하세요.
-- 여러 번 실행해도 안전해요. (이전 버전을 실행했어도 다시 실행하면 기존 데이터는 그대로 두고 필요한 것만 추가돼요)

-- 1) 체크 기록 (사람 + 장소마다 한 줄)
create table if not exists public.picks (
  person     text not null,
  place_id   text not null,
  choice     text not null check (choice in ('must', 'ok', 'pass')),
  updated_at timestamptz not null default now(),
  primary key (person, place_id)
);

-- 2) 후보 목록 (기본 후보 + 화면에서 추가한 후보 모두 여기에 저장)
create table if not exists public.places (
  id          text primary key,
  cat         text not null check (cat in ('sight', 'night', 'food', 'shop', 'trip')),
  name        text not null check (char_length(name) between 1 and 40),
  zh          text,
  area        text,
  duration    text,
  description text check (char_length(description) <= 200),
  emoji       text,
  added_by    text not null,
  created_at  timestamptz not null default now()
);
alter table public.places add column if not exists updated_at timestamptz not null default now();

-- 3) 장소별 사진 (장소당 1장)
create table if not exists public.place_photos (
  place_id   text primary key,
  url        text not null,
  path       text,
  added_by   text,
  updated_at timestamptz not null default now()
);

-- 4) API 접근 권한 (GRANT)
--    2026년 5월 30일 이후 만든 Supabase 프로젝트는 테이블을 만들어도
--    API(supabase-js)에서 자동으로 접근할 수 없어요. 직접 권한을 줘야 해요.
--    ※ 이게 빠져 있으면 '꼭/괜찮아/패스' 저장이 실패해요.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.picks, public.places, public.place_photos to anon, authenticated;

-- 5) RLS(행 단위 보안) 켜고, 링크를 가진 사람이 읽고 쓸 수 있게 허용
alter table public.picks        enable row level security;
alter table public.places       enable row level security;
alter table public.place_photos enable row level security;

do $$
declare t text;
begin
  foreach t in array array['picks', 'places', 'place_photos'] loop
    execute format('drop policy if exists "anon read"   on public.%I', t);
    execute format('drop policy if exists "anon insert" on public.%I', t);
    execute format('drop policy if exists "anon update" on public.%I', t);
    execute format('drop policy if exists "anon delete" on public.%I', t);
    execute format('create policy "anon read"   on public.%I for select to anon, authenticated using (true)', t);
    execute format('create policy "anon insert" on public.%I for insert to anon, authenticated with check (true)', t);
    execute format('create policy "anon update" on public.%I for update to anon, authenticated using (true) with check (true)', t);
    execute format('create policy "anon delete" on public.%I for delete to anon, authenticated using (true)', t);
  end loop;
end $$;

-- 6) 실시간 동기화 (상대방의 체크·추가·수정·삭제가 새로고침 없이 바로 보이게)
alter table public.picks        replica identity full;
alter table public.places       replica identity full;
alter table public.place_photos replica identity full;

do $$
declare t text;
begin
  foreach t in array array['picks', 'places', 'place_photos'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- 7) 사진 저장소 (Storage 버킷: 공개 읽기, 파일당 최대 5MB, 이미지만)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('place-photos', 'place-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "place-photos read"   on storage.objects;
drop policy if exists "place-photos upload" on storage.objects;
drop policy if exists "place-photos delete" on storage.objects;

create policy "place-photos read"   on storage.objects for select to anon, authenticated using (bucket_id = 'place-photos');
create policy "place-photos upload" on storage.objects for insert to anon, authenticated with check (bucket_id = 'place-photos');
create policy "place-photos delete" on storage.objects for delete to anon, authenticated using (bucket_id = 'place-photos');

-- 8) 기본 후보 29곳 넣기
--    이미 있는 id는 건너뛰어요. 화면에서 수정한 내용은 덮어쓰지 않아요.
--    ※ 기본 후보를 화면에서 '삭제'한 뒤 이 파일을 다시 실행하면 그 후보가 다시 생겨요.
insert into public.places (id, cat, name, zh, area, duration, description, emoji, added_by, created_at) values
  ('bund', 'sight', '와이탄', '外滩', '황푸', '1~2시간', '황푸강변을 따라 유럽풍 근대 건물이 늘어선 상하이 대표 산책로. 낮에도 좋고 밤엔 필수.', '🏦', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '0 seconds'),
  ('yuyuan', 'sight', '예원 & 성황묘', '豫园', '황푸', '2~3시간', '명나라 시대 정원과 전통 상점가. 처마 지붕 거리 구경, 군것질하기 좋아요.', '🏯', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '1 seconds'),
  ('pearl', 'sight', '동방명주', '东方明珠', '루자쭈이', '1~2시간', '상하이 스카이라인의 상징인 방송탑. 유리 바닥 전망대가 유명해요.', '🗼', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '2 seconds'),
  ('tower', 'sight', '상하이타워 전망대', '上海中心', '루자쭈이', '1~2시간', '중국에서 가장 높은 빌딩. 초고속 엘리베이터로 올라가 도시 전체를 내려다봐요.', '🏙', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '3 seconds'),
  ('xintiandi', 'sight', '신천지', '新天地', '황푸', '1~2시간', '스쿠먼(石库门) 전통 가옥을 개조한 카페·레스토랑 거리. 분위기 좋은 저녁 코스.', '🧱', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '4 seconds'),
  ('kpgov', 'sight', '대한민국 임시정부 청사', '大韩民国临时政府旧址', '황푸', '1시간', '신천지 근처에 있어 함께 묶기 좋아요. 한국인이라면 한 번쯤 들러볼 만한 곳.', '🇰🇷', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '5 seconds'),
  ('tianzifang', 'sight', '티엔즈팡', '田子坊', '황푸', '1~2시간', '좁은 골목에 공방, 소품숍, 카페가 미로처럼 이어진 동네. 구경하는 재미가 있어요.', '🏮', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '6 seconds'),
  ('wukang', 'sight', '우캉루 & 우캉맨션', '武康路', '쉬후이', '1~2시간', '플라타너스 가로수와 옛 프랑스 조계지 건물. 사진 찍기 좋은 산책 코스.', '🌳', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '7 seconds'),
  ('jingan', 'sight', '징안사', '静安寺', '징안', '40분', '도심 빌딩 숲 한가운데 있는 황금빛 사찰. 쇼핑 동선 중간에 들르기 좋아요.', '🛕', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '8 seconds'),
  ('museum', 'sight', '상하이 박물관', '上海博物馆', '인민광장', '2시간', '청동기, 도자기, 서화 컬렉션이 훌륭한 박물관. 비 오는 날 일정으로도 좋아요.', '🏺', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '9 seconds'),
  ('lujun', 'sight', '루쉰공원 (매헌 윤봉길 기념관)', '鲁迅公园', '홍커우', '1시간', '윤봉길 의사 의거 현장. 현지인들의 공원 일상도 볼 수 있어요.', '🕊', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '10 seconds'),
  ('bundnight', 'night', '와이탄 야경', '外滩夜景', '황푸', '1시간', '강 건너 루자쭈이 빌딩 숲에 불이 켜지는 순간이 하이라이트. 조명 시간에 맞춰 가요.', '✨', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '11 seconds'),
  ('cruise', 'night', '황푸강 유람선', '黄浦江游览', '와이탄', '40분~1시간', '배 위에서 양쪽 야경을 한 번에. 짧은 일정이면 페리로 강만 건너도 분위기 나요.', '🛳', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '12 seconds'),
  ('northbund', 'night', '북와이탄 산책', '北外滩', '홍커우', '1시간', '와이탄보다 한산하게 루자쭈이 야경을 볼 수 있는 강변 산책로.', '🌉', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '13 seconds'),
  ('rooftop', 'night', '와이탄 루프탑 바', '屋顶酒吧', '황푸', '1~2시간', '와이탄 건물 꼭대기 바에서 야경 보며 한잔. 자리 경쟁이 있으니 예약 추천.', '🍸', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '14 seconds'),
  ('xlb', 'food', '샤오롱바오', '小笼包', '곳곳', '1시간', '육즙 가득한 상하이 대표 만두. 예원의 난샹만두점이 가장 유명해요.', '🥟', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '15 seconds'),
  ('shengjian', 'food', '셩지엔바오', '生煎包', '곳곳', '30분', '바닥을 바삭하게 구운 군만두. 샤오양셩지엔 같은 체인점에서 쉽게 먹어요.', '🍳', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '16 seconds'),
  ('crab', 'food', '털게 (따자셰)', '大闸蟹', '곳곳', '1~2시간', '가을·초겨울 제철 별미. 게살 국수나 게알 요리로도 즐길 수 있어요.', '🦀', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '17 seconds'),
  ('hongshao', 'food', '상하이 가정식 (홍샤오러우)', '本帮菜', '곳곳', '1~2시간', '달큰한 간장 양념 돼지고기 조림 등 상하이 본방요리 코스.', '🍖', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '18 seconds'),
  ('hotpot', 'food', '훠궈', '火锅', '곳곳', '1~2시간', '하이디라오 같은 훠궈 맛집. 밤늦게까지 하는 곳이 많아 마지막 일정으로 좋아요.', '🍲', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '19 seconds'),
  ('breakfast', 'food', '현지 아침 (총유빙·또우장)', '早餐', '곳곳', '30분', '파기름 전병, 두유, 유타오로 먹는 현지식 아침. 골목 가게에서 저렴하게.', '🥢', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '20 seconds'),
  ('roastery', 'shop', '스타벅스 리저브 로스터리', '星巴克臻选烘焙工坊', '징안', '1시간', '세계 최대급 스타벅스 매장. 로스팅 설비 구경만으로도 볼거리예요.', '☕', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '21 seconds'),
  ('nanjingrd', 'shop', '난징동루 보행가', '南京东路', '황푸', '1~2시간', '와이탄으로 이어지는 쇼핑 거리. 밤에 네온사인이 켜지면 더 화려해요.', '🛍', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '22 seconds'),
  ('anfu', 'shop', '안푸루', '安福路', '쉬후이', '1~2시간', '감각적인 카페와 편집숍이 모인 요즘 핫한 거리. 우캉루와 걸어서 묶기 좋아요.', '🧁', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '23 seconds'),
  ('ifc', 'shop', 'IFC몰 / 루자쭈이 쇼핑', '国金中心', '루자쭈이', '1~2시간', '대형 쇼핑몰. 전망대 일정과 묶어 식사·쇼핑까지 한 번에.', '🏬', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '24 seconds'),
  ('zhujiajiao', 'trip', '주가각 수향마을', '朱家角', '칭푸', '반나절', '운하와 돌다리가 있는 물의 마을. 지하철로 갈 수 있어 근교 중 접근성이 좋아요.', '🛶', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '25 seconds'),
  ('suzhou', 'trip', '쑤저우 당일치기', '苏州', '근교', '하루', '고속철로 금방 가는 정원의 도시. 졸정원과 핑장루 운하 거리가 유명해요.', '🌸', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '26 seconds'),
  ('wuzhen', 'trip', '우전 수향마을', '乌镇', '근교', '하루', '밤 조명이 아름다운 대규모 수향마을. 시간 여유가 있으면 1박도 좋아요.', '🏮', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '27 seconds'),
  ('disney', 'trip', '상하이 디즈니랜드', '上海迪士尼', '푸둥', '하루', '하루를 통째로 쓰는 테마파크. 놀이기구 좋아하면 고려해 볼 만해요.', '🏰', '기본', timestamptz '2026-01-01 00:00:00+00' + interval '28 seconds')
on conflict (id) do nothing;
