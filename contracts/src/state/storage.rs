use super::model::State;
use cw_storage_plus::Item;

pub const STATE: Item<State> = Item::new("state");
