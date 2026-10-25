alter table rounds add column pulse text not null default 'none';

alter table rounds alter column pulse drop default;
