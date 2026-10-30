use std::sync::Arc;
use std::time::Duration;

use axum::http::StatusCode;
use tokio::sync::Notify;

use crate::models::{Chair, Ride};
use crate::{AppState, Error};

pub fn internal_routes() -> axum::Router<AppState> {
    axum::Router::new().route(
        "/api/internal/matching",
        axum::routing::get(internal_get_matching),
    )
}

// マッチングはバックグラウンドのワーカーが実行する。外部からの呼び出しには何もせず応答する。
async fn internal_get_matching() -> StatusCode {
    StatusCode::NO_CONTENT
}

// 通知を受けたとき、または1秒経過したときにマッチングを実行する。
// 1秒のタイムアウトは通知漏れの保険。
pub fn spawn_matcher(pool: sqlx::MySqlPool, notify: Arc<Notify>) {
    tokio::spawn(async move {
        loop {
            let _ = tokio::time::timeout(Duration::from_secs(1), notify.notified()).await;

            // 割り当てに成功した間は続けて実行する
            loop {
                match run_matching(&pool).await {
                    Ok(true) => continue,
                    Ok(false) => break,
                    Err(e) => {
                        tracing::error!("matching failed: {e}");
                        break;
                    }
                }
            }
        }
    });
}

// 椅子を割り当てたら true を返す
async fn run_matching(pool: &sqlx::MySqlPool) -> Result<bool, Error> {
    // MEMO: 一旦最も待たせているリクエストに適当な空いている椅子マッチさせる実装とする。おそらくもっといい方法があるはず…
    // まだマッチしていない椅子の一番古いrideを呼び出す
    let Some(ride): Option<Ride> =
        sqlx::query_as("SELECT * FROM rides WHERE chair_id IS NULL ORDER BY created_at LIMIT 1")
            .fetch_optional(pool)
            .await?
    else {
        return Ok(false);
    };

    for _ in 0..10 {
        let Some(matched): Option<Chair> =
            sqlx::query_as("SELECT * FROM chairs INNER JOIN (SELECT id FROM chairs WHERE is_active = TRUE ORDER BY RAND() LIMIT 1) AS tmp ON chairs.id = tmp.id LIMIT 1")
                .fetch_optional(pool)
                .await?
        else {
            return Ok(false);
        };

        let empty: bool = sqlx::query_scalar(
            "SELECT COUNT(*) = 0 FROM (SELECT COUNT(chair_sent_at) = 6 AS completed FROM ride_statuses WHERE ride_id IN (SELECT id FROM rides WHERE chair_id = ?) GROUP BY ride_id) is_completed WHERE completed = FALSE",
        )
        .bind(&matched.id)
        .fetch_one(pool)
        .await?;

        if empty {
            sqlx::query("UPDATE rides SET chair_id = ? WHERE id = ?")
                .bind(matched.id)
                .bind(ride.id)
                .execute(pool)
                .await?;
            return Ok(true);
        }
    }

    Ok(false)
}
