use godot::{classes::{ProjectSettings}, prelude::*};

pub fn globalize_path(path: &str) -> String {
    ProjectSettings::singleton().globalize_path(path).into()
}
