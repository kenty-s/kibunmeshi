#!/bin/bash
set -e

# 残っている pid を毎回掃除
rm -f tmp/pids/server.pid

# 本番起動前に DB を準備する
bundle exec rails db:prepare

# 明示的に実行する時だけ seed
if [ "${RUN_SEEDS:-false}" = "true" ]; then
  echo "RUN_SEEDS=true -> db:seed"
  bundle exec rails db:seed
fi

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

# サーバー起動（RenderはPORT環境変数を要求）
exec bundle exec rails server -b 0.0.0.0 -p "${PORT:-3000}"
