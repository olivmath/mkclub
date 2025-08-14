use cosmwasm_std::{Addr, DepsMut, MessageInfo, Response};

use crate::error::ContractError;
use crate::state::STATE;

pub fn increment(deps: DepsMut, owner: Addr) -> Result<Response, ContractError> {
    STATE.update(deps.storage, |mut state| -> Result<_, ContractError> {
        state.count += 1;
        state.owner = owner;
        Ok(state)
    })?;

    Ok(Response::new().add_attribute("action", "increment"))
}

pub fn reset(deps: DepsMut, info: MessageInfo, count: i32) -> Result<Response, ContractError> {
    STATE.update(deps.storage, |mut state| -> Result<_, ContractError> {
        if info.sender != state.owner {
            return Err(ContractError::Unauthorized {});
        }
        state.count = count;
        Ok(state)
    })?;
    Ok(Response::new().add_attribute("action", "reset"))
}
