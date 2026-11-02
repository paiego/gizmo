create table rounds_new (
  id text primary key,
  run_id text not null references runs (id),
  round_index integer not null check (round_index >= 0),
  body text not null,
  top_part text not null,
  side_part text not null,
  hole text not null,
  color text not null,
  pulse text not null default 'none',
  choice_count integer not null check (choice_count between 3 and 8),
  correct integer not null check (correct in (0, 1)),
  unique (run_id, round_index),
  check (top_part <> 'none' or side_part <> 'none')
);

insert into rounds_new (
  id, run_id, round_index, body, top_part, side_part,
  hole, color, pulse, choice_count, correct
)
select
  id, run_id, round_index, body, top_part, side_part,
  hole, color, pulse, choice_count, correct
from rounds;

drop table rounds;

alter table rounds_new rename to rounds;
