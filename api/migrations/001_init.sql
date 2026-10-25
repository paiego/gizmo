create table players (
  id uuid primary key,
  name_key text not null unique,
  display_name text not null,
  created_at timestamptz not null default now()
);

create table runs (
  id uuid primary key,
  player_id uuid not null references players (id),
  score integer not null check (score >= 0),
  wrong_count integer not null check (wrong_count = 3),
  played_at timestamptz not null default now()
);

create table rounds (
  id uuid primary key,
  run_id uuid not null references runs (id),
  round_index integer not null check (round_index >= 0),
  body text not null,
  top_part text not null,
  side_part text not null,
  hole text not null,
  color text not null,
  choice_count integer not null check (choice_count between 3 and 6),
  correct boolean not null,
  unique (run_id, round_index),
  check (top_part <> 'none' or side_part <> 'none')
);

create index runs_player_score_idx
  on runs (player_id, score desc, played_at asc);
