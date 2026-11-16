use serde::{Deserialize, Serialize};
use url::Url;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Definition {
    pub term: String,
    pub part_of_speech: String,
    pub text: String,
    pub source_url: String,
    #[serde(default)]
    pub hanja: Option<String>,
    #[serde(default)]
    pub custom: bool,
    #[serde(default)]
    pub note: Option<String>,
}

pub fn source_url(term: &str) -> String {
    let mut url = Url::parse("https://en.wiktionary.org/wiki/").expect("constant dictionary URL");
    url.path_segments_mut().unwrap().pop_if_empty().push(term);
    url.set_fragment(Some("Korean"));
    url.into()
}
