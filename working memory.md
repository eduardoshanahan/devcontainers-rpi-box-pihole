# Confirm the installed script no longer references domainNeeded
rg -n "domainNeeded|scalar_keys" /srv/apps/pihole/sync/sync.py

# Confirm the container is using the current script

docker start pihole-sync

grep -nE "domainNeeded|scalar_keys" /srv/apps/pihole/sync/sync.py

docker exec pihole-sync python3 - <<'PY'
import inspect, sync
print(inspect.getsource(sync))
PY

docker start pihole-sync

docker logs --tail 20 pihole-sync

docker stop pihole-sync



docker stop pihole-sync
docker start pihole-sync
docker logs --since 5s pihole-sync
