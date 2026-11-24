//! QML query replies contain the serialized value (including null for no match),
//! or an object with an `error` string. Mutation slots retain their existing
//! empty-string-on-success contract. Keep domain Result types until this boundary.
use serde::Serialize;
use serde_json::{json, Value};

pub fn error(message: impl std::fmt::Display) -> Value {
    json!({ "error": message.to_string() })
}

pub fn reply<T: Serialize>(result: Result<T, String>) -> Value {
    result
        .and_then(|value| serde_json::to_value(value).map_err(|err| err.to_string()))
        .unwrap_or_else(error)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn absent_values_and_failures_are_distinct() {
        assert_eq!(reply(Ok(None::<String>)), Value::Null);
        assert_eq!(
            reply::<String>(Err("Database unavailable".into())),
            json!({"error":"Database unavailable"})
        );
    }
}
