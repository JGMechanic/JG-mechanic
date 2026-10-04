-- JG Mobile Mechanic V3.9
-- Adds a timestamp used to notify the customer when progress photos are uploaded.

alter table public.jobs
add column if not exists photo_updated_at timestamptz;

create or replace function public.notify_customer_job_photos()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  customer_user_id uuid;
  vehicle_reg text;
begin
  if old.photo_updated_at is not distinct from new.photo_updated_at then
    return new;
  end if;

  select c.user_id, v.registration
  into customer_user_id, vehicle_reg
  from public.customers c
  left join public.vehicles v on v.id = new.vehicle_id
  where c.id = new.customer_id;

  if customer_user_id is null then
    return new;
  end if;

  perform net.http_post(
    url := 'https://ytwgtywxfmsjpgoytoxx.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'role', 'customer',
      'user_id', customer_user_id,
      'title', 'JG Mobile Mechanic',
      'body', 'New progress photos have been added for ' || coalesce(vehicle_reg, 'your vehicle') || '.'
    ),
    timeout_milliseconds := 5000
  );

  return new;
end;
$$;

drop trigger if exists notify_customer_job_photos on public.jobs;
create trigger notify_customer_job_photos
after update of photo_updated_at
on public.jobs
for each row
execute function public.notify_customer_job_photos();
