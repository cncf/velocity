select count(distinct sha) as commits from gha_commits where dup_created_at >= '{{dtfrom}}' and dup_created_at < '{{dtto}}' and (lower(dup_committer_login) {{exclude_bots}})
