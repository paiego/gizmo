create table players (
  id text primary key,
  name_key text not null unique,
  display_name text not null,
  created_at text not null
);

create table runs (
  id text primary key,
  player_id text not null references players (id),
  score integer not null check (score >= 0),
  wrong_count integer not null check (wrong_count = 3),
  played_at text not null
);

create table rounds (
  id text primary key,
  run_id text not null references runs (id),
  round_index integer not null check (round_index >= 0),
  body text not null,
  top_part text not null,
  side_part text not null,
  hole text not null,
  color text not null,
  choice_count integer not null check (choice_count between 3 and 6),
  correct integer not null check (correct in (0, 1)),
  unique (run_id, round_index),
  check (top_part <> 'none' or side_part <> 'none')
);

create index runs_player_score_idx
  on runs (player_id, score desc, played_at asc);
