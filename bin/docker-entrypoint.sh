#!/bin/bash
set -e

# 残っている pid を毎回掃除
rm -f tmp/pids/server.pid

# lockfile 更新後でも named volume 側の gems を自動で同期する
if ! bundle check > /dev/null 2>&1; then
  echo "bundle check failed -> bundle install"
  bundle install --jobs 4 --retry 3
fi

# 本番起動前に DB を準備する
bundle exec rails db:prepare

# ADMIN_* 環境変数があれば管理者ユーザーを用意する
bundle exec rails admin:ensure_user

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
