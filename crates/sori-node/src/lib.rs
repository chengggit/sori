#![deny(clippy::all)]

use std::path::PathBuf;

use napi::{bindgen_prelude::*, Error};
use napi_derive::napi;

/// Point the native analyzer at the bundled Kiwi library and model directory.
#[napi]
pub fn init(resources_dir: String) -> Result<()> {
    sori_core::init(PathBuf::from(resources_dir)).map_err(Error::from_reason)
}

/// Open and migrate the local library database at startup.
#[napi]
pub fn init_library(directory: String) -> Result<()> {
    sori_core::init_library(PathBuf::from(directory)).map_err(Error::from_reason)
}

/// Execute one core command. JSON strings keep the bridge boundary explicit;
/// the desktop main process parses the reply into a plain object.
#[napi]
pub async fn invoke(command: String, payload: String) -> Result<String> {
    let payload: serde_json::Value =
        serde_json::from_str(&payload).map_err(|error| Error::from_reason(error.to_string()))?;
    let reply = sori_core::invoke(&command, &payload);
    serde_json::to_string(&reply).map_err(|error| Error::from_reason(error.to_string()))
}
