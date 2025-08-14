use cw_storage_plus::Item;
use super::model::State;

pub const STATE: Item<State> = Item::new("state");