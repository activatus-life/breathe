-- Local example programme matching the mockups. Protocol timings are placeholders
-- until confirmed with the course author.

insert into public.programs (id, name, description, duration_weeks, is_published)
values (
  '00000000-0000-0000-0000-000000000001',
  'And Breathe: Six Weeks',
  'Build carbon dioxide tolerance, recover better between efforts, stay calm under stress.',
  6,
  true
);

insert into public.program_blocks (program_id, name, week_start, week_end) values
  ('00000000-0000-0000-0000-000000000001', 'Foundations', 1, 2),
  ('00000000-0000-0000-0000-000000000001', 'Carbon dioxide tolerance block', 3, 4),
  ('00000000-0000-0000-0000-000000000001', 'Consolidation', 5, 6);

-- Pulse, base test, then four holds with three-minute recoveries, then pulse.
insert into public.protocol_steps (program_id, week_number, step_order, step_type, duration_seconds, instructions)
select
  '00000000-0000-0000-0000-000000000001',
  week.number,
  step.step_order,
  step.step_type::public.protocol_step_type,
  step.duration_seconds,
  step.instructions
from generate_series(1, 6) as week(number)
cross join (values
  (1, 'pulse', 60, 'Count your pulse for 60 seconds, or read it from your watch.'),
  (2, 'base', null, 'Baseline test.'),
  (3, 'hold', null, 'Hold 1.'),
  (4, 'recovery', 180, 'Breathe normally.'),
  (5, 'hold', null, 'Hold 2.'),
  (6, 'recovery', 180, 'Breathe normally.'),
  (7, 'hold', null, 'Hold 3.'),
  (8, 'recovery', 180, 'Breathe normally.'),
  (9, 'hold', null, 'Hold 4.'),
  (10, 'pulse', 60, 'Record your finishing heart rate.')
) as step(step_order, step_type, duration_seconds, instructions);

insert into public.cohorts (program_id, name, starts_on)
values ('00000000-0000-0000-0000-000000000001', 'October cohort', '2026-09-21');
