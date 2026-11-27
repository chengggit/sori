//! Every fallible bridge operation uses this envelope, synchronously or in a
//! completion signal. Request IDs, observable properties and player controls
//! are lifecycle/state APIs, not operation results.
use serde::Serialize;
use serde_json::Value;

#[derive(Debug, Serialize)]
pub struct Response<T> {
    ok: bool,
    data: Option<T>,
    error: String,
}

impl<T> From<Result<T, String>> for Response<T> {
    fn from(result: Result<T, String>) -> Self {
        match result {
            Ok(data) => Self {
                ok: true,
                data: Some(data),
                error: String::new(),
            },
            Err(error) => Self {
                ok: false,
                data: None,
                error,
            },
        }
    }
}

pub fn reply<T: Serialize>(result: Result<T, String>) -> Value {
    serde_json::to_value(Response::from(result)).unwrap_or_else(
        |error| serde_json::json!({"ok": false, "data": null, "error": error.to_string()}),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn unit_absence_data_and_failure_share_one_contract() {
        assert_eq!(reply(Ok(())), json!({"ok":true,"data":null,"error":""}));
        assert_eq!(reply(Ok(None::<String>)), reply(Ok(())));
        assert_eq!(
            reply(Ok(vec![1, 2])),
            json!({"ok":true,"data":[1,2],"error":""})
        );
        assert_eq!(
            reply::<String>(Err("Unavailable".into())),
            json!({"ok":false,"data":null,"error":"Unavailable"})
        );
    }
}
