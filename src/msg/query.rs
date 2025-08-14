use cosmwasm_schema::{cw_serde, QueryResponses};
use super::response::GetCountResponse;

#[cw_serde]
#[derive(QueryResponses)]
pub enum QueryMsg {
    // GetCount returns the current count as a json-encoded number
    #[returns(GetCountResponse)]
    GetCount {},
}
