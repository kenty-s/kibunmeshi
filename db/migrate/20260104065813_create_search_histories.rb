class CreateSearchHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :search_histories do |t|
      t.references :user, null: false, foreign_key: true          # 誰の履歴かを紐付け（必須）
      t.references :dish, foreign_key: true                       # どの料理が結果だったか（nilも許容）
      t.jsonb :query_params, null: false, default: {}             # 検索条件を柔軟に保存
      t.datetime :executed_at, null: false                        # いつ検索したかを保持（並び替え用）
      t.timestamps                                                # created_at/updated_at
    end
    add_index :search_histories, [ :user_id, :executed_at ]         # ユーザーごとの履歴を時系列で高速に取得
  end
end
