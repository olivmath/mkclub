use cosmwasm_schema::cw_serde;

#[cw_serde]
pub enum ExecuteMsg {
    IncrementCounter {},
    ResetCounter { count: i32 },
}