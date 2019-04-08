-- select count(*) as pushes from gha_events where type = 'PushEvent' and created_at >= '{{dtfrom}}' and created_at < '{{dtto}}' and (lower(dup_actor_login) {{exclude_bots}})
select count(*) as pushes from gha_events where type = 'PushEvent' and created_at >= '{{dtfrom}}' and created_at < '{{dtto}}'
